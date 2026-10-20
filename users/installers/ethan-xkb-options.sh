#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: merge declared xkb options into ~/.config/kxkbrc (privileged) ---
# kxkbrc keeps every xkb option in ONE comma-separated [Layout] Options key, so a
# plain kwriteconfig6 per line (the plasmarc pattern) would clobber options set in
# the GUI. Instead: read the current list, drop entries in the same group as a
# declared option (xkb allows one caps:*, one ctrl:*, ...), append the declared
# ones, write back. Also asserts ResetOldOptions=true (the GUI's "Configure
# keyboard options" box): without it Plasma ignores Options entirely. That makes
# Plasma's list replace the system XKBOPTIONS (/etc/default/keyboard; empty on
# this box). Idempotent. Takes effect on next login.
deploy_ethan_xkb_options() {
    local conf="$REPO_ROOT/users/ethan/kde-xkb-options.conf" opt cur new
    [ -f "$conf" ] || return
    review_gate "users/ethan/kde-xkb-options.conf" || { say "   skipped kde-xkb-options"; return; }
    as_ethan_kcfg() { if [ "$ME" = ethan ]; then "$@"; else sudo -u ethan "$@"; fi; }

    cur="$(as_ethan_kcfg kreadconfig6 --file kxkbrc --group Layout --key Options)"
    new="$cur"
    while read -r opt _; do
        [ -n "$opt" ] || continue
        case "$opt" in \#*) continue ;; esac
        # drop same-group entries (group = text before ':'), then append
        # (grep exits 1 when nothing survives, e.g. an empty list - not an error)
        new="$(tr ',' '\n' <<<"$new" | { grep -v -e '^$' -e "^${opt%%:*}:" || true; } | paste -sd, -)"
        new="${new:+$new,}$opt"
    done < "$conf"

    as_ethan_kcfg kwriteconfig6 --file kxkbrc --group Layout --key ResetOldOptions true
    if [ "$new" = "$cur" ]; then
        say "ethan-tier: kxkbrc Options unchanged ($cur)"
        return
    fi
    as_ethan_kcfg kwriteconfig6 --file kxkbrc --group Layout --key Options "$new"
    say "ethan-tier: kxkbrc Options '$cur' -> '$new' (next login)"
}
deploy_ethan_xkb_options
