#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: jellyfin-daemon-guard user unit (reload only, NEVER enable) ---
# The unit file (jellyfin-daemon-guard.service, under users/ethan/.config/systemd/user)
# is already copied by ethan-config above. Unlike clip-discord / steam-tracker, this
# unit must NOT be enabled: it has no [Install], must never start at boot (Docker is
# disabled then), and is started on demand by the "Jellyfin Server" launcher each
# session. So all this step does is daemon-reload so systemd picks up the new/changed
# unit. See services/docker.md.
deploy_jellyfin_guard() {
    local uid; uid="$(id -u ethan)"
    if [ "$ME" = ethan ]; then
        systemctl --user daemon-reload || true
    else
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload || true
    fi
    say "ethan-tier: jellyfin-daemon-guard unit reloaded (on-demand; not enabled)"
}
deploy_jellyfin_guard
