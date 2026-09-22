#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# dev's own files -> run as dev directly (re-exec if invoked by ethan/root).
if [ "$ME" != dev ]; then
    exec sudo -u dev -H bash "$0" "$@"
fi

# --- dev-tier: box-local memory -> ~/.agents/memory (flat, Claude Code format),
#     symlinked into ~/.claude/projects/-<project>/memory, AND rendered into the
#     DeepSeek Harness memory-standard root (~/.dsh/memory) for the memory-standard
#     plugin. One subdir per project under users/dev/memory/<proj>/; the live Claude
#     path dash-encodes the project's absolute path (srv-dev -> -srv-dev). Same trust
#     model as dev's skills (dev's OWN home — no review gate). Additive. ---
deploy_dev_memory() {
    local root="$REPO_ROOT/users/dev/memory" d name dst
    [ -d "$root" ] || { say "dev-memory: no $root — skipping"; return; }
    for d in "$root"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        dst="$AGENTS_DIR/memory"
        mkdir -p "$dst"
        cp -a "$d." "$dst/"
        say "dev-tier: installed memory ($name) -> $dst"
        ensure_agents_symlink "$dst" "$CLAUDE_DIR/projects/-$name/memory"
        # DeepSeek Harness: same notes, memory-standard (mm) layout.
        if [ -f "$DEV_ENV_REPO/lib/memory-standard.py" ]; then
            python3 "$DEV_ENV_REPO/lib/memory-standard.py" render --src "$d" --dst "$DSH_HOME_DIR/memory" || \
                warn "dsh memory render failed (see above)"
        else
            say "dev-memory: no $DEV_ENV_REPO/lib/memory-standard.py — skipping dsh memory"
        fi
    done
}
deploy_dev_memory
