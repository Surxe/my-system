#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: copy dev's own PATH executables into ~dev/.local/bin (dev's files) ---
# Same trust model as dev-bashrc / dev's CLAUDE.md: dev already controls its home,
# so there is NO review gate. ~/.local/bin is on dev's PATH via Debian's stock
# ~/.profile (the same dir todo-dev installs `todo` into). Additive: refreshes/adds
# executables; does NOT prune bins removed from the repo.
deploy_dev_bin() {
    local src="$REPO_ROOT/users/dev/localbin" dst="$DEV_HOME/.local/bin" f base
    [ -d "$src" ] || { say "dev-bin: no $src — skipping"; return; }
    for f in "$src"/*; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        if [ "$ME" = dev ]; then
            install -D -m 0755 "$f" "$dst/$base"
        else
            sudo -u dev install -D -m 0755 "$f" "$dst/$base"
        fi
        say "dev-tier: installed $dst/$base"
    done
}
deploy_dev_bin
