# spotifixed

Plays a cached Spotify playlist through mpv, with the current lyric line in an overlay
above fullscreen windows. The tool lives in its own repo
(`/srv/dev/repos/spotifixed`), which knows nothing about this machine's accounts;
everything about who runs what is here.

## The split

| Part | Runs as | From | Why |
|------|---------|------|-----|
| `sync`, `status`, `pin`, `align` | dev | the repo and its `.venv` | Network, yt-dlp and a dev-writable tree: the usual hop. The cache it fills is dev's. `align` also uses the GPU. |
| `serve` (the daemon, owns mpv) | ethan | a reviewed copy in `~/.local/share/spotifixed` | mpv needs Ethan's audio server, which dev cannot reach. |
| `overlay` | ethan | the same copy | It needs Ethan's Wayland display, which dev cannot reach. |
| `ctl` | ethan | the same copy | Same code as the daemon; a loopback HTTP call. |
| `start` | ethan | the same copy | The daemon with the overlay as its child, plus the page in the browser. |

The daemon cannot be hopped to dev and merely "play through" Ethan's audio: mpv's
control socket can run programs, so mpv and whatever controls it must be one user.
Opening Ethan's audio or display socket to dev was rejected; it would hand dev the
microphone, the clipboard and the ability to draw over the session.

The ethan side has no virtualenv and nothing pip-installed. Those commands use only the
Python standard library (plus the system GTK bindings for the overlay) and are run by
`/usr/bin/python3 -s`.

## Commands

```bash
spotifixed-sync <playlist-url>     # fetch into the cache (as dev); resumable
spotifixed-sync status [playlist]  # what is cached
spotifixed-sync pin <track> <url>  # choose a track's audio by hand
spotifixed-sync align [playlist]   # time each word against the audio (as dev, on the GPU); resumable
spotifixed start                   # everything: daemon, overlay, and the page in the browser
spotifixed serve                   # the daemon alone; then open http://127.0.0.1:8765/
spotifixed overlay [--demo]        # the lyric line; --demo for positioning
spotifixed ctl toggle              # play, pause, next, prev, stop, seek, volume
```

## Starting and stopping it

The **Spotifixed** launcher (menu and desktop) opens a terminal window (foot) running
`spotifixed start`. That window is the application: it stays open while the player
runs, closing it (or Ctrl-C in it) stops the daemon, mpv and the overlay together, and
the daemon saves its place first. Clicking the launcher while it is already running
only opens the page. The window is held open after exit only when `start` failed.

The launcher's icon is the package's own `server/static/icon.svg`, read from the
deployed copy; the page uses the same file as its favicon. `foot --app-id=spotifixed`
gives the window the launcher's identity, so the taskbar shows that icon instead of the
terminal's. The launcher needs `foot` installed (`apt install foot`). It does not use
Konsole because Konsole ignores `--desktopfile`: it applies the option only after
it has already published its app data, so every Konsole window reports `org.kde.konsole`.

## Where the pieces are

| Piece | Source | Deployed to | By |
|-------|--------|-------------|----|
| Launchers | `users/ethan/localbin/spotifixed{,-sync,.run.sh}` | `~ethan/.local/bin/` | `ethan-bin` |
| Menu and desktop entry | `users/ethan/desktop-entries/spotifixed.desktop` | `~ethan/.local/share/applications/`, `~ethan/Desktop/` | `desktop-entries` |
| Settings | `users/ethan/.config/spotifixed/settings.conf` | `~ethan/.config/spotifixed/` | `ethan-config` |
| The package | `spotifixed` repo, `spotifixed/` (tracked files only) | `~ethan/.local/share/spotifixed/spotifixed/` | `installers/spotifixed.sh` |
| Token whitelist | `system/etc-sudoers.d/devbridge-env` (`APIFY_TOKEN`) | `/etc/sudoers.d/` | `root-tier` |
| Shared data | `spotifixed` repo, `cache/` and `state/` | in place (group `developers`, setgid, group-writable) | `installers/spotifixed.sh` |

The package copy is review-gated as one tree against the spotifixed repo's
approved default branch (`review_gate_tree_in` in `installers/common.sh`): if any tracked file
differs, the deploy shows the `--stat` and asks once. Untracked files are never copied.
Until that repo's work is merged to its default branch, every deploy will ask.

Settings are repo-authoritative: edit `settings.conf` here and redeploy. To try a value
first, pass it as a flag (`spotifixed overlay --overlay-margin-y 200 --demo`).

## The secret

Only fetching a playlist that is not cached yet needs one: an Apify API token, in
`~ethan/.config/spotifixed/secrets.env` (mode 600, hand-maintained, one line:
`APIFY_TOKEN=...`). `spotifixed-sync` loads it for `sync` alone and carries it
across the hop with `--preserve-env`, as `clip-post` does with its webhook. See
[sudo-policy.md](../users-and-permissions/sudo-policy.md#env-whitelist-for-the-bridge).

## Sharing the cache between the two accounts

The tool forces no file permissions. dev fills `cache/`; the daemon reads it and writes
only per-track lyric offsets into `state/`. Both directories are group `developers`,
setgid and group-writable (asserted on every deploy), and both launchers run with
`umask 002`, so either account can replace the other's files.
