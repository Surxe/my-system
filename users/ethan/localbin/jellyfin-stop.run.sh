#!/usr/bin/env bash
# HAND-MAINTAINED. "Stop Jellyfin" launcher — the teardown half of the on-demand
# Docker lifecycle. Brings the Jellyfin container down, THEN stops the daemon, socket,
# and containerd, returning the machine to zero Docker footprint. Sequenced (not
# event-driven) so nothing races the container removal. NOPASSWD systemctl stop is
# scoped in /etc/sudoers.d/docker-daemon. See services/docker.md. Deployed (COPIED,
# review-gated) into ethan's ~/.local/bin by install.sh — never run from the repo tree.
set -uo pipefail
cd /srv/dev/repos/media-server || exit 1

# Hold the Konsole window open only when something is worth reading: a warning/error
# was emitted, or --debug (JELLYFIN_DEBUG=1) was passed. A clean run closes itself.
DEBUG="${JELLYFIN_DEBUG:-0}"
case "${1:-}" in --debug|-d|debug) DEBUG=1 ;; esac
warned=0

pause() { [ -t 0 ] && { echo; read -n1 -rp "${1:-Press any key to close…}"; echo; }; }
warn()  { warned=1; echo "$@"; }
# End-of-run hold: pause only if a warning fired or we're in debug.
pause_if_needed() { { [ "$warned" = 1 ] || [ "$DEBUG" = 1 ]; } && pause "$@"; }

if systemctl is-active --quiet docker.service; then
  # Stop + remove the container while the daemon is up. If `down` can't remove it
  # (e.g. a container wedged "marked for removal"), force it so the daemon isn't left
  # holding a zombie.
  docker compose down || docker rm -f jellyfin 2>/dev/null || true
  if ! sudo /usr/bin/systemctl stop docker.service docker.socket containerd.service; then
    warn "!! Failed to stop the Docker services — check 'systemctl status docker.service'."
    pause; exit 1
  fi
  echo "Jellyfin and the Docker daemon are stopped."
else
  echo "Docker daemon is already stopped — nothing to do."
fi
pause_if_needed
exit 0
