#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: dev's own Claude skills -> ~dev/.claude/skills (dev's own files) ---
deploy_dev_skills() {
    local src="$REPO_ROOT/users/dev/skills" dst="$DEV_HOME/.claude/skills"
    [ -d "$src" ] || { say "dev-skills: no $src — skipping"; return; }
    # Additive copy: refreshes/adds skills; does NOT prune skills deleted from the repo.
    if [ "$ME" = dev ]; then
        mkdir -p "$dst"; cp -a "$src/." "$dst/"
    else
        sudo -u dev mkdir -p "$dst"; sudo -u dev cp -a "$src/." "$dst/"
    fi
    say "dev-tier: installed skills -> $dst"
}
deploy_dev_skills
