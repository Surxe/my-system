#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: dev's own Claude memory -> ~dev/.claude/projects/-<proj>/memory ---
# One subdir per Claude project under users/dev/memory/<proj>/; the live path
# dash-encodes the project's absolute path, so <proj> is that path with '/'->'-'
# and the leading dash dropped (srv-dev -> -srv-dev). Same trust model as dev's
# skills (dev's OWN home — no review gate). Additive copy: refreshes/adds memory
# files, does NOT prune ones deleted from the repo.
deploy_dev_memory() {
    local root="$REPO_ROOT/users/dev/memory" d name dst
    [ -d "$root" ] || { say "dev-memory: no $root — skipping"; return; }
    for d in "$root"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        dst="$DEV_HOME/.claude/projects/-$name/memory"
        if [ "$ME" = dev ]; then
            mkdir -p "$dst"; cp -a "$d." "$dst/"
        else
            sudo -u dev mkdir -p "$dst"; sudo -u dev cp -a "$d." "$dst/"
        fi
        say "dev-tier: installed memory ($name) -> $dst"
    done
}
deploy_dev_memory
