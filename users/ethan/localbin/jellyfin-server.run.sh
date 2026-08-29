#!/usr/bin/env bash
# HAND-MAINTAINED (was /add-shortcut-generated; do not regenerate via add-shortcut).
# "Jellyfin Server" launcher — the ONLY start path for the Docker daemon on this box.
# The daemon is disabled at boot; this script starts it on demand, brings Jellyfin up,
# arms the teardown guard, and opens the web UI. To stop: use Jellyfin's Dashboard ->
# Shut Down (the container exits and stays down; jellyfin-daemon-guard.service then
# stops the daemon). See my-system: services/docker.md, users-and-permissions/
# sudo-policy.md, and the media-server repo README. Deployed (COPIED, review-gated)
# into ethan's ~/.local/bin by install.sh — never run from the repo tree.
set -uo pipefail
cd /srv/dev/repos/media-server || exit 1
# Start the daemon on demand (NOPASSWD, /etc/sudoers.d/docker-daemon); it pulls in
# docker.socket + containerd as dependencies.
sudo /usr/bin/systemctl start docker.service
docker compose up -d
# Arm the teardown watcher for THIS session (not enabled at boot; started here).
systemctl --user start jellyfin-daemon-guard.service
sleep 3
xdg-open http://localhost:8096
status=$?
if [ -t 0 ]; then
  echo
  read -n1 -rp "Jellyfin up (exit $status). Shut it down from the Jellyfin Dashboard. Press any key to close…"
  echo
fi
exit "$status"
