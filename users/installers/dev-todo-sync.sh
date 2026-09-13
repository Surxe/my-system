#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: dev's todo cross-box sync. Deploys dev's user systemd units that
# push the shared todo store to the hub on every commit ("push on add"), ensures
# the `hub` git remote on dev's todo clone, and lingers dev so the watcher runs
# without a login session. All dev's own files -> no review gate. Idempotent. ---
#
# The SSH key + real hub host/IP live only in dev's ~/.ssh (config alias 'todo-hub'),
# never in this repo (see users/dev/.bashrc.d/15-todo.sh). The hub URL here is the
# alias form, so no address is committed.
# The DATA store is its own repo (todo-store), synced only over the hub — never
# GitHub. The `todo` code repo goes to GitHub separately and needs no hub remote.
TODO_CLONE="/srv/dev/repos/todo-store"
HUB_URL="ssh://todo-hub/srv/dev/repos/todo-store.git"

as_dev() { if [ "$ME" = dev ]; then "$@"; else sudo -u dev "$@"; fi; }

deploy_dev_todo_sync() {
    local srcdir="$REPO_ROOT/users/dev/.config/systemd/user"
    local dstdir="$DEV_HOME/.config/systemd/user"
    if [ ! -e "$srcdir/todo-sync.path" ]; then
        say "dev-todo-sync: no units in $srcdir — skipping"; return
    fi

    as_dev mkdir -p "$dstdir"
    as_dev install -m 0644 "$srcdir/todo-sync.path"    "$dstdir/todo-sync.path"
    as_dev install -m 0644 "$srcdir/todo-sync.service" "$dstdir/todo-sync.service"
    say "dev-tier: installed todo-sync.{path,service} -> $dstdir"

    # Ensure the 'hub' remote on dev's todo clone (idempotent; alias, no IP committed).
    if as_dev test -d "$TODO_CLONE/.git"; then
        if as_dev git -C "$TODO_CLONE" remote get-url hub >/dev/null 2>&1; then
            as_dev git -C "$TODO_CLONE" remote set-url hub "$HUB_URL"
        else
            as_dev git -C "$TODO_CLONE" remote add hub "$HUB_URL"
        fi
        # Ensure master tracks hub/master. A clone made via `git clone` gets this for
        # free; one made via `git init` + `remote add` does not, so set it here so
        # plain `git pull`/status work cleanly (sync_push no longer relies on it).
        as_dev git -C "$TODO_CLONE" fetch -q hub 2>/dev/null || true
        as_dev git -C "$TODO_CLONE" branch --set-upstream-to=hub/master master 2>/dev/null || true
        say "dev-tier: todo-store 'hub' remote -> $HUB_URL"
    elif as_dev git clone -o hub -q "$HUB_URL" "$TODO_CLONE" 2>/dev/null; then
        # Fresh box: clone the store from the hub, and mark it group-shared so both
        # dev and ethan can commit (mirrors the store's dual-writer perms).
        as_dev git -C "$TODO_CLONE" config core.sharedRepository group
        say "dev-tier: cloned todo-store from $HUB_URL"
    else
        say "dev-todo-sync: could not reach $HUB_URL — create the store hub first, then re-run"
    fi

    # dev is headless (no login session): linger so the path unit runs at boot.
    # Needs root; install.sh's operator is ethan/root.
    if command -v loginctl >/dev/null 2>&1; then
        if [ "$ME" = root ]; then
            loginctl enable-linger dev 2>/dev/null || true
        else
            sudo loginctl enable-linger dev 2>/dev/null \
                || say "   (could not enable-linger dev — needs root; watcher runs only during a dev session until then)"
        fi
    fi

    # Enable the watcher in dev's user systemd manager.
    local uid; uid="$(id -u dev)"
    as_dev env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload 2>/dev/null || true
    if as_dev env XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user enable --now todo-sync.path 2>/dev/null; then
        say "dev-tier: enabled todo-sync.path (push-on-add)"
    else
        say "   (could not enable todo-sync.path — needs dev's user manager running; re-run after linger/login)"
    fi
}
deploy_dev_todo_sync
