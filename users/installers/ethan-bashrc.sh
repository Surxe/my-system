#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: copy .bashrc.d modules into ethan's home (privileged) ---
deploy_ethan_tier() {
    local d="$ETHAN_HOME/.bashrc.d" f base rel
    for f in "$REPO_ROOT"/users/ethan/.bashrc.d/*.sh; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="users/ethan/.bashrc.d/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        install -D -m 0644 "$f" "$d/$base"
        say "ethan-tier: installed $d/$base"
    done
    # Harden the Debian non-interactive guard in ethan's ~/.bashrc (mirrors what
    # dev-env's deploy_bashrc does for dev): `return` at top level only works when
    # sourced, so an executed ~/.bashrc errors on that line. Idempotent rewrite.
    if [ -f "$ETHAN_HOME/.bashrc" ] && grep -q '^[[:space:]]*\*) return;;' "$ETHAN_HOME/.bashrc"; then
        sed -i 's#^\([[:space:]]*\)\*) return;;#\1*) return 2>/dev/null || exit 0;;#' "$ETHAN_HOME/.bashrc"
        say "ethan-tier: hardened non-interactive guard in $ETHAN_HOME/.bashrc"
    fi
}
deploy_ethan_tier
