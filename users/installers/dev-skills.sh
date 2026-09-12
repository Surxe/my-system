#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# dev's own files -> run as dev directly (re-exec if invoked by ethan/root).
if [ "$ME" != dev ]; then
    exec sudo -u dev -H bash "$0" "$@"
fi

# --- dev-tier: box-local skills -> ~/.agents/skills (the neutral root), symlinked
#     into ~/.claude/skills for Claude Code. The DeepSeek Harness scans
#     ~/.agents/skills natively (user-agents root), so one copy serves both. Additive
#     copy: refreshes/adds skills; does NOT prune skills deleted from the repo. ---
deploy_dev_skills() {
    local src="$REPO_ROOT/users/dev/skills" dst="$AGENTS_DIR/skills"
    [ -d "$src" ] || { say "dev-skills: no $src — skipping"; return; }
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
    ensure_agents_symlink "$dst" "$CLAUDE_DIR/skills"
    say "dev-tier: installed skills -> $dst"
}
deploy_dev_skills
