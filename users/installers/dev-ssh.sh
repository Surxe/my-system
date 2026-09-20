#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: copy ethan's todo/home-server SSH into dev's own ~/.ssh.
# Ethan owns the SSH for todo-hub / home-server; dev needs its own readable copy
# so it can auth to the hub (a symlink into ethan's 0700 home is unreadable by
# dev and cannot work). Copies are dev-owned, 0600. This deliberately parks a
# private key in dev's space (Ethan's explicit choice, 2026-09-20) rather than
# keeping it ethan-only. Idempotent: re-copies only when the source differs. ---

deploy_dev_ssh() {
    local ethan_ssh="$ETHAN_HOME/.ssh"
    local dev_ssh="$DEV_HOME/.ssh"

    # Ensure dev's .ssh exists (may pre-exist with other, non-todo configs).
    as_dev mkdir -p "$dev_ssh"
    as_dev chmod 700 "$dev_ssh"

    # config + key + pubkey: copy ethan's copy into dev's own ~/.ssh.
    # The invoking user (ethan or root) can read the source; dev writes the dest.
    for file in config id_todo id_todo.pub; do
        local src="$ethan_ssh/$file"
        local dst="$dev_ssh/$file"
        [ -e "$src" ] || continue

        # Every dst-side test/removal MUST run as dev: dev's home is 0700, so the
        # invoking user (ethan) can't even stat $dst, and a dst-side test run as
        # ethan silently returns false.
        #
        # Idempotency: skip if dev's copy already matches the source byte-for-byte.
        # ethan/root opens src for reading (the `< "$src"` redirect); dev's cmp
        # reads its own dst. A leftover symlink into ethan's 0700 home makes cmp
        # (as dev) fail to read, so it falls through to the rewrite below.
        if as_dev cmp -s /dev/stdin "$dst" < "$src" 2>/dev/null; then
            continue
        fi

        # Remove any prior file/symlink AS DEV before writing, or dev's tee would
        # follow a leftover symlink back into ethan's (unwritable) home.
        as_dev rm -f "$dst"

        # ethan/root opens src for reading (the `< "$src"` redirect); dev's tee
        # writes the dest, so the copy is owned by dev.
        as_dev tee "$dst" >/dev/null < "$src"
        case "$file" in
            *.pub) as_dev chmod 644 "$dst" ;;
            *)     as_dev chmod 600 "$dst" ;;
        esac
        say "dev-ssh: copied $file into dev's ~/.ssh"
    done

    say "dev-tier: copied SSH config + todo key into dev's ~/.ssh"
}

deploy_dev_ssh
