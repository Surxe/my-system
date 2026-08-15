#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: steam-price-tracker resume-refresh (secret + systemd wiring) ---
# The two systemd USER units (under users/ethan/.config/systemd/user) and the two
# PATH scripts (steam-price-refresh, steam-price-resume-watch) are already deployed
# by ethan-config / ethan-bin above. This step does the two things those generic
# copies can't:
#   (a) ensure the Ethan-owned SMTP secret exists WITHOUT ever storing it in this
#       repo. Created only if absent (never overwritten, never read/echoed), and
#       only when install.sh is run interactively AS ethan (his private chmod-600
#       file). The repo carries only smtp.env.example.
#   (b) reload + enable the resume watcher in Ethan's user systemd.
deploy_steam_tracker() {
    local cfgdir="$ETHAN_HOME/.config/steam-price-tracker" env
    env="$cfgdir/smtp.env"
    local is_ethan=0; [ "$ME" = ethan ] && is_ethan=1
    local uid; uid="$(id -u ethan)"

    # (a) secret — presence check must run as ethan (dev cannot traverse his home).
    local present=0
    if [ "$is_ethan" = 1 ]; then
        [ -f "$env" ] && present=1
    else
        sudo -u ethan test -f "$env" && present=1
    fi

    if [ "$present" = 1 ]; then
        say "ethan-tier: steam smtp.env already present - leaving it untouched"
    elif [ "$is_ethan" = 1 ] && [ -t 0 ]; then
        say "ethan-tier: steam-price-tracker SMTP secret not found."
        local u p
        read -r -p "   Gmail sender address (blank = skip email setup): " u </dev/tty
        if [ -n "$u" ]; then
            read -r -s -p "   Gmail App Password (16 chars, hidden): " p </dev/tty; echo
            ( umask 077; mkdir -p "$cfgdir"
              printf 'STEAM_TRACKER_SMTP_USER=%s\nSTEAM_TRACKER_SMTP_PASSWORD=%s\n' "$u" "$p" > "$env" )
            chmod 600 "$env"
            say "   wrote $env (chmod 600)"
        else
            say "   skipped - email stays disabled until $env exists"
        fi
    else
        say "ethan-tier: steam smtp.env missing - run install.sh AS ethan in a"
        say "   terminal to enter it, or create $env by hand (chmod 600)."
    fi

    # (b) reload + enable the resume watcher in ethan's user systemd.
    if [ "$is_ethan" = 1 ]; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now steam-price-resume-watch.service \
            || say "!! could not enable steam-price-resume-watch.service"
    else
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload || true
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user \
            enable --now steam-price-resume-watch.service \
            || say "!! could not enable watcher as ethan (needs an active ethan session)"
    fi
    say "ethan-tier: steam-price-tracker resume watcher wired"
}
deploy_steam_tracker
