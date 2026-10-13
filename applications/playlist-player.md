# playlist-player

Plays a cached Spotify playlist through mpv, with the current lyric line in an overlay
above fullscreen windows. The tool lives in its own repo
(`/srv/dev/repos/playlist-player`), which knows nothing about this machine's accounts;
everything about who runs what is here.

## The split

| Part | Runs as | From | Why |
|------|---------|------|-----|
| `sync`, `status`, `pin` | dev | the repo and its `.venv` | Network, yt-dlp and a dev-writable tree: the usual hop. The cache it fills is dev's. |
| `serve` (the daemon, owns mpv) | ethan | a reviewed copy in `~/.local/share/playlist-player` | mpv needs Ethan's audio server, which dev cannot reach. |
| `overlay` | ethan | the same copy | It needs Ethan's Wayland display, which dev cannot reach. |
| `ctl` | ethan | the same copy | Same code as the daemon; a loopback HTTP call. |

The daemon cannot be hopped to dev and merely "play through" Ethan's audio: mpv's
control socket can run programs, so mpv and whatever controls it must be one user.
Opening Ethan's audio or display socket to dev was rejected; it would hand dev the
microphone, the clipboard and the ability to draw over the session.

The ethan side has no virtualenv and nothing pip-installed. Those commands use only the
Python standard library (plus the system GTK bindings for the overlay) and are run by
`/usr/bin/python3 -s`.

## Commands

```bash
playlist-player-sync <playlist-url>     # fetch into the cache (as dev); resumable
playlist-player-sync status [playlist]  # what is cached
playlist-player-sync pin <track> <url>  # choose a track's audio by hand
playlist-player serve                   # the daemon; then open http://127.0.0.1:8765/
playlist-player overlay [--demo]        # the lyric line; --demo for positioning
playlist-player ctl toggle              # play, pause, next, prev, stop, seek, volume
```

## Where the pieces are

| Piece | Source | Deployed to | By |
|-------|--------|-------------|----|
| Launchers | `users/ethan/localbin/playlist-player{,-sync}` | `~ethan/.local/bin/` | `ethan-bin` |
| Settings | `users/ethan/.config/playlist-player/settings.conf` | `~ethan/.config/playlist-player/` | `ethan-config` |
| The package | `playlist-player` repo, `playlist_player/` (tracked files only) | `~ethan/.local/share/playlist-player/playlist_player/` | `installers/playlist-player.sh` |
| Token whitelist | `system/etc-sudoers.d/devbridge-env` (`APIFY_TOKEN`) | `/etc/sudoers.d/` | `root-tier` |
| Shared data | `playlist-player` repo, `cache/` and `state/` | in place (group `developers`, setgid, group-writable) | `installers/playlist-player.sh` |

The package copy is review-gated as one tree against the playlist-player repo's
approved default branch (`review_gate_tree_in` in `installers/common.sh`): if any tracked file
differs, the deploy shows the `--stat` and asks once. Untracked files are never copied.
Until that repo's work is merged to its default branch, every deploy will ask.

Settings are repo-authoritative: edit `settings.conf` here and redeploy. To try a value
first, pass it as a flag (`playlist-player overlay --overlay-margin-y 200 --demo`).

## The secret

Only fetching a playlist that is not cached yet needs one: an Apify API token, in
`~ethan/.config/playlist-player/secrets.env` (mode 600, hand-maintained, one line:
`APIFY_TOKEN=...`). `playlist-player-sync` loads it for `sync` alone and carries it
across the hop with `--preserve-env`, as `clip-post` does with its webhook. See
[sudo-policy.md](../users-and-permissions/sudo-policy.md#env-whitelist-for-the-bridge).

## Sharing the cache between the two accounts

The tool forces no file permissions. dev fills `cache/`; the daemon reads it and writes
only per-track lyric offsets into `state/`. Both directories are group `developers`,
setgid and group-writable (asserted on every deploy), and both launchers run with
`umask 002`, so either account can replace the other's files.
