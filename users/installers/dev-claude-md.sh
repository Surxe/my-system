#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# dev's own files -> run as dev directly (re-exec if invoked by ethan/root).
if [ "$ME" != dev ]; then
    exec sudo -u dev -H bash "$0" "$@"
fi

# --- dev-tier: dev's own global instructions -> ~/.agents/AGENTS.md, symlinked
#     to Claude's global instruction path (~/.claude/CLAUDE.md) and the DeepSeek
#     Harness's (~/.dsh/AGENTS.md). Copied, not symlinked (dev already controls
#     its home). The repo source stays `CLAUDE.md` (the build pipeline is
#     CLAUDE.md-centric); the live neutral name is `AGENTS.md`. ---
deploy_dev_tier() {
    local src="$REPO_ROOT/users/dev/CLAUDE.md" dst="$AGENTS_DIR/AGENTS.md"
    [ -e "$src" ] || { say "dev-tier: no $src (build phase / run.sh should have created it)"; return; }
    install -D -m 0644 "$src" "$dst"
    say "dev-tier: installed (copy) $dst"
    ensure_agents_symlink "$dst" "$CLAUDE_DIR/CLAUDE.md"
    ensure_agents_symlink "$dst" "$DSH_HOME_DIR/AGENTS.md"
}
deploy_dev_tier
