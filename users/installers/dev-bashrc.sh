#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: copy this repo's box-specific .bashrc.d fragments into dev's home.
# These are dev's OWN files (dev controls its home), so there is no review gate —
# same trust model as dev's CLAUDE.md/skills. Copy-based and additive: it refreshes
# only the fragments this repo owns and never prunes, so it coexists with the
# portable fragments dev-env deploys into the same dir (e.g. 10-claude.sh). Runs as
# dev, re-execing via sudo -u dev when the operator is ethan/root. ---
deploy_dev_bashrc() {
    local src="$REPO_ROOT/users/dev/.bashrc.d" dst="$DEV_HOME/.bashrc.d" f base
    [ -d "$src" ] || { say "dev-bashrc: no $src — skipping"; return 0; }
    for f in "$src"/*.sh; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        if [ "$ME" = dev ]; then
            install -D -m 0644 "$f" "$dst/$base"
        else
            sudo -u dev install -D -m 0644 "$f" "$dst/$base"
        fi
        say "dev-tier: installed $dst/$base"
    done
}
deploy_dev_bashrc
