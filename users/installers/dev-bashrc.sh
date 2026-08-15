#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: copy dev's own .bashrc.d modules into ~dev/.bashrc.d (dev's files) ---
# No review gate: these are dev's OWN files (dev already controls its home), same
# trust model as dev's CLAUDE.md/skills. Additive copy: refreshes/adds fragments;
# does NOT prune fragments deleted from the repo. Dev's ~/.bashrc must source
# ~/.bashrc.d/*.sh (one-time loader bootstrap; see users/dev/.bashrc.d/README.md).
deploy_dev_bashrc() {
    local src="$REPO_ROOT/users/dev/.bashrc.d" dst="$DEV_HOME/.bashrc.d" f
    [ -d "$src" ] || { say "dev-bashrc: no $src — skipping"; return; }
    for f in "$src"/*.sh; do
        [ -e "$f" ] || continue
        if [ "$ME" = dev ]; then
            install -D -m 0644 "$f" "$dst/$(basename "$f")"
        else
            sudo -u dev install -D -m 0644 "$f" "$dst/$(basename "$f")"
        fi
        say "dev-tier: installed $dst/$(basename "$f")"
    done
}
deploy_dev_bashrc
