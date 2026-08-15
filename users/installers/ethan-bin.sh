#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: copy PATH executables into ethan's ~/.local/bin (privileged) ---
# For tools ethan runs directly (e.g. todo-capture). A COPY, never a symlink, so
# dev-writable working-tree code never executes as ethan except by explicit,
# review-gated deploy. ~/.local/bin is on ethan's PATH (Debian ~/.profile).
deploy_ethan_bin() {
    local d="$ETHAN_HOME/.local/bin" f base rel
    for f in "$REPO_ROOT"/users/ethan/localbin/*; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="users/ethan/localbin/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        install -D -m 0755 "$f" "$d/$base"
        say "ethan-tier: installed $d/$base"
    done
}
deploy_ethan_bin
