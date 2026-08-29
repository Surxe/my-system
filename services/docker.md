# Docker

Docker Engine (rootful) + Compose plugin, installed from docker.com's Debian repo
(see the media-server repo `bootstrap.sh`). `ethan` is in the `docker` group.

## On-demand daemon (Jellyfin-gated)

The **only** thing on this box that uses Docker is the Jellyfin media server
(`/srv/dev/repos/media-server`). To keep Docker off the machine while gaming, the
daemon does **not** run at boot — it is started on demand and torn down explicitly.
It is driven by two desktop launchers (paired start/stop), not by Jellyfin's own UI.

> **Why not Jellyfin's Dashboard -> Shut Down?** The `linuxserver/jellyfin` image runs
> Jellyfin under s6 supervision (PID 1 in the container is s6, not Jellyfin). An in-app
> shutdown is immediately restarted by the supervisor and the *container never exits*,
> so it cannot drive host teardown. The Stop launcher does it directly instead.

**Boot state (one-time, run by ethan — dev has no systemd-admin access):**

```
sudo systemctl disable docker.service
sudo systemctl disable --now docker.socket
sudo systemctl disable --now containerd.service
```

All three end up `disabled`. `docker.service` has `Requires=docker.socket` and
`Wants=containerd.service`, so starting it on demand pulls both back up.

**Start** — the "Jellyfin Server" launcher
(`users/ethan/localbin/jellyfin-server.run.sh`), the only start path: runs
`sudo systemctl start docker.service` (NOPASSWD, see
[sudo-policy.md](../users-and-permissions/sudo-policy.md#ethan---root-the-docker-daemon-bridge)),
then `docker compose up -d`, then opens the web UI.

**Stop** — the "Stop Jellyfin" launcher
(`users/ethan/localbin/jellyfin-stop.run.sh`): runs `docker compose down` (stops +
removes the container while the daemon is still up — no race), then
`sudo systemctl stop docker.service docker.socket containerd.service`. Footprint
returns to zero. Idempotent: a no-op if the daemon is already down.

The stop is deliberately **sequenced, not event-driven** — an earlier design used a
`docker events` guard to stop the daemon on the container's death, but that raced the
`compose down` that triggered it and left containerd running. The two-launcher model
is simpler and deterministic.

## Files

- Compose + restart policy: media-server repo (`docker-compose.yml`, README).
- Launchers: `users/ethan/localbin/jellyfin-server.run.sh` (start),
  `users/ethan/localbin/jellyfin-stop.run.sh` (stop);
  desktop entries `users/ethan/desktop-entries/jellyfin-{server,stop}.desktop`.
- NOPASSWD grant: `system/etc-sudoers.d/docker-daemon`
  ([sudo-policy.md](../users-and-permissions/sudo-policy.md#ethan---root-the-docker-daemon-bridge)).
