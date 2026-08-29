#!/usr/bin/env bash
# HAND-MAINTAINED (was /add-shortcut-generated; do not regenerate via add-shortcut).
# "Jellyfin Server" launcher — the ONLY start path for the Docker daemon on this box.
# The daemon is disabled at boot; this starts it on demand (which pulls docker.socket
# + containerd up via unit deps), brings Jellyfin up, and opens the web UI.
#
# To STOP, use the "Stop Jellyfin" launcher (jellyfin-stop.run.sh) — NOT Jellyfin's
# Dashboard -> Shut Down. The linuxserver image runs Jellyfin under s6, so an in-app
# shutdown is just restarted by the supervisor; the container never exits.
# See my-system: services/docker.md, users-and-permissions/sudo-policy.md, and the
# media-server README. Deployed (COPIED, review-gated) into ethan's ~/.local/bin by
# install.sh — never run from the repo tree.
set -uo pipefail
cd /srv/dev/repos/media-server || exit 1

pause() { [ -t 0 ] && { echo; read -n1 -rp "${1:-Press any key to close…}"; echo; }; }

# Start the daemon on demand (NOPASSWD, /etc/sudoers.d/docker-daemon). Requires=
# pulls docker.socket; Wants= pulls containerd.
if ! sudo /usr/bin/systemctl start docker.service; then
  echo "!! Failed to start docker.service — nothing else attempted."
  pause; exit 1
fi

# Bring the container up. If a previous run left it wedged (e.g. a half-removed
# container "marked for removal"), clear it once and retry rather than pretending
# success. `up -d` is idempotent when the container is healthy.
if ! docker compose up -d; then
  echo "!! 'docker compose up' failed — clearing a stuck container and retrying…"
  docker rm -f jellyfin 2>/dev/null || true
  if ! docker compose up -d; then
    echo "!! Jellyfin failed to start (see the error above). Daemon left running so you can inspect;"
    echo "   use the \"Stop Jellyfin\" launcher to shut it back down."
    pause; exit 1
  fi
fi

sleep 3
xdg-open http://localhost:8096 >/dev/null 2>&1 || true
echo "Jellyfin is up at http://localhost:8096"
pause "Stop it with the \"Stop Jellyfin\" launcher. Press any key to close…"
exit 0
