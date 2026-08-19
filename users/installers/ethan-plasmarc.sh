#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: assert declared ~/.config/plasmarc tweaks (privileged) ---
# Writes ONLY the [<group>]<key> entries listed in the conf, via kwriteconfig6 —
# merge-safe (every other plasmarc key untouched) and idempotent. Takes effect on
# next plasmashell reload/login (a file write doesn't hot-reload plasmashell).
deploy_ethan_plasmarc() {
    local conf="$REPO_ROOT/users/ethan/kde-plasmarc.conf" group key value
    [ -f "$conf" ] || return
    review_gate "users/ethan/kde-plasmarc.conf" || { say "   skipped kde-plasmarc"; return; }
    while read -r group key value; do
        [ -n "$group" ] || continue
        case "$group" in \#*) continue ;; esac
        [ -n "$key" ] && [ -n "$value" ] || continue
        if [ "$ME" = ethan ]; then
            kwriteconfig6 --file plasmarc --group "$group" --key "$key" "$value"
        else
            sudo -u ethan kwriteconfig6 --file plasmarc --group "$group" --key "$key" "$value"
        fi
        say "ethan-tier: plasmarc [$group] $key=$value"
    done < "$conf"
}
deploy_ethan_plasmarc
