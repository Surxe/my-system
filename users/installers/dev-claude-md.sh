#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: dev's own CLAUDE.md (copied, not symlinked — dev already controls it) ---
deploy_dev_tier() {
    local src="$REPO_ROOT/users/dev/CLAUDE.md" dst="$DEV_HOME/.claude/CLAUDE.md"
    [ -e "$src" ] || { say "dev-tier: no $src (build phase / run.sh should have created it)"; return; }
    if [ "$ME" = dev ]; then
        install -D -m 0644 "$src" "$dst"
    else
        sudo -u dev install -D -m 0644 "$src" "$dst"
    fi
    say "dev-tier: installed (copy) $dst"
}
deploy_dev_tier
