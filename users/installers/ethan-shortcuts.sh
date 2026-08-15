#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: assert declared KDE global shortcuts (privileged) ---
# Writes ONLY the [services][<id>] _launch keys listed in the conf, via
# kwriteconfig6 — merge-safe (every other shortcut untouched) and idempotent.
# Binds keys to already-deployed .desktop launchers, so run AFTER those. Takes
# effect on next login (a file write doesn't hot-reload kglobalaccel).
deploy_ethan_shortcuts() {
    local conf="$REPO_ROOT/users/ethan/kde-global-shortcuts.conf" id key
    [ -f "$conf" ] || return
    review_gate "users/ethan/kde-global-shortcuts.conf" || { say "   skipped kde-global-shortcuts"; return; }
    while read -r id key; do
        [ -n "$id" ] || continue
        case "$id" in \#*) continue ;; esac
        [ -n "$key" ] || continue
        if [ "$ME" = ethan ]; then
            kwriteconfig6 --file kglobalshortcutsrc --group services --group "$id" --key _launch "$key"
        else
            sudo -u ethan kwriteconfig6 --file kglobalshortcutsrc --group services --group "$id" --key _launch "$key"
        fi
        say "ethan-tier: shortcut $key -> $id"
    done < "$conf"
}
deploy_ethan_shortcuts
