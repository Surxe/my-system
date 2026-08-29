# Docker

Docker Engine (rootful) + Compose plugin, installed from docker.com's Debian repo
(see the media-server repo `bootstrap.sh`). `ethan` is in the `docker` group.

## On-demand daemon (Jellyfin-gated)

The **only** thing on this box that uses Docker is the Jellyfin media server
(`/srv/dev/repos/media-server`). To keep Docker off the machine while gaming, the
daemon does **not** run at boot — it is started on demand and torn down again the
moment Jellyfin is shut down.

**Boot state (one-time, run by ethan — dev has no systemd-admin access):**

```
sudo systemctl disable docker.service
sudo systemctl disable --now docker.socket
sudo systemctl disable --now containerd.service   # pulled back in as a dependency at launch
```

**Start (the only start path):** the "Jellyfin Server" launcher
(`users/ethan/localbin/jellyfin-server.run.sh`) runs
`sudo systemctl start docker.service` (NOPASSWD, see
[sudo-policy.md](../users-and-permissions/sudo-policy.md#ethan---root-the-docker-daemon-bridge)),
then `docker compose up -d`, then arms the teardown guard, then opens the web UI.

**Stop (chain of command):**

1. In Jellyfin: **Dashboard -> Shut Down**. The server process exits.
2. With `restart: "no"` in the compose file, the `jellyfin` container exits and
   **stays** down (it does not auto-restart).
3. `jellyfin-daemon-guard.service` (a systemd **user** unit, armed by the launcher,
   **not** enabled at boot) is watching `docker events ... event=die`. It catches the
   container's death and runs `sudo systemctl stop docker.service docker.socket`.
4. The daemon (and containerd) go down. Footprint returns to zero until the next launch.

The `die` filter also fires on a manual `docker stop` / `docker compose down`, so those
routes trigger the same teardown.

## Files

- Daemon lifecycle + compose: media-server repo (`docker-compose.yml`, README).
- Launcher: `users/ethan/localbin/jellyfin-server.run.sh`.
- Guard unit: `users/ethan/.config/systemd/user/jellyfin-daemon-guard.service`
  (reloaded, not enabled, by `users/installers/jellyfin-guard.sh`).
- NOPASSWD grant: `system/etc-sudoers.d/docker-daemon`
  ([sudo-policy.md](../users-and-permissions/sudo-policy.md#ethan---root-the-docker-daemon-bridge)).
