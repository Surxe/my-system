#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: desktop launchers -> ethan's app menu + desktop (privileged) ---
# Each .desktop deploys to BOTH locations; only the .desktop is copied here.
# The Exec target for ethan-executed code must point at a DEPLOYED copy (e.g.
# ~/.local/bin, populated by ethan-bin) — never at the dev-writable repo tree,
# which would let a dev-tree edit run as ethan with no review gate. Only assets
# (Icon SVGs) and cross-repo runners are referenced in place by design.
deploy_desktop_entries() {
    local apps="$ETHAN_HOME/.local/share/applications" desk="$ETHAN_HOME/Desktop"
    local f base rel any=0
    for f in "$REPO_ROOT"/users/ethan/desktop-entries/*.desktop; do
        [ -e "$f" ] || continue
        any=1
        base="$(basename "$f")"; rel="users/ethan/desktop-entries/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        install -D -m 0644 "$f" "$apps/$base"   # menu entry (no exec bit / trust needed)
        install -D -m 0755 "$f" "$desk/$base"   # desktop icon (KDE needs the exec bit)
        say "ethan-tier: installed $base -> menu + desktop"
    done
    [ "$any" = 1 ] || return
    # Refresh KDE's menu cache so new entries appear without a re-login (best effort).
    if [ "$ME" = ethan ]; then
        kbuildsycoca6 >/dev/null 2>&1 || kbuildsycoca5 >/dev/null 2>&1 || true
    else
        sudo -u ethan kbuildsycoca6 >/dev/null 2>&1 || sudo -u ethan kbuildsycoca5 >/dev/null 2>&1 || true
    fi
}
deploy_desktop_entries
