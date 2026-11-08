---
name: add-playlist
description: >-
  Add a Spotify playlist to spotifixed, or refresh one already added: check
  whether it is cached, hand Ethan the one sync command that needs his Apify
  token, then report what landed, what changed, and what needs a hand-picked
  audio. Use whenever Ethan wants to add, fetch, sync, refresh or update a
  playlist in spotifixed, or see what changed on Spotify.
---

# Add a playlist to spotifixed

The setup (who runs what, where the token lives) is in
`/srv/dev/repos/my-system/applications/spotifixed.md`. What matters here:

- Fetching a playlist's track list needs the Apify token, which lives only in
  `~ethan/.config/spotifixed/secrets.env`. dev cannot read it, so **Ethan
  runs the sync**, through his `spotifixed-sync` launcher (it loads the
  token and hops to dev).
- Everything else works as dev, from the repo:
  `cd /srv/dev/repos/spotifixed && .venv/bin/python -m spotifixed <cmd>`.

## Step 1 -- Check the cache

Take the playlist URL, `spotify:playlist:` URI, or bare ID from Ethan (ask only if
none was given), and run as dev:

```
.venv/bin/python -m spotifixed status '<playlist>'
```

- **"is not cached"**: new playlist, go to Step 2.
- **A summary**: the track list is already cached, so no token is needed. Say
  so; if Ethan wants it completed, run
  `.venv/bin/python -m spotifixed sync '<playlist>'` yourself (it is
  resumable). If he wants it updated to match Spotify, see Refreshing below.

## Step 2 -- Hand off the sync (Ethan only)

Tell Ethan to run this in **his own terminal** (not a `!` command here, which
runs as dev and cannot reach the token):

```
spotifixed-sync '<playlist url>'
```

Mention:
- The track list is one paid Apify run (about $0.01), sent once and cached.
- It downloads audio, lyrics and covers for every track, which takes a while on
  a large playlist. It can be stopped and run again; it picks up where it left off.
- Exit status 2 means Apify returned fewer tracks than the playlist holds.
- If `~/.config/spotifixed/secrets.env` is missing, the sync names
  `APIFY_TOKEN`; the format is in `/srv/dev/repos/spotifixed/secrets.env.example`.

Then stop and wait for Ethan to say it finished.

## Step 3 -- Report

Once Ethan says it is done, run `status '<playlist>'` as dev and summarize:
tracks, how many are ready, and any flagged `review`. For a review track, the
candidates are in `cache/misses.json`; if Ethan picks one, run as dev
`pin <track-id> <url>` then `sync '<playlist>' --track <track-id>`.

Offer the optional word timing, which needs no token and runs as dev on the GPU
(about five seconds a track):
`.venv/bin/python -m spotifixed align '<playlist>'`.

The new playlist shows up in the player's page on its own; nothing needs restarting.

## Refreshing a cached playlist

When Ethan wants a cached playlist brought in line with Spotify, fetching the
track list again is a paid run that needs the token, so it goes to Ethan. Hand
him, for his own terminal:

```
spotifixed-sync '<playlist url>' --refresh-tracklist --only tracklist
```

`--only tracklist` fetches the list and nothing else. The refresh archives the
old list under `cache/playlists/<id>/history/` and prints what changed itself;
do not diff track lists by hand or by reading them. Once he says it ran, show
the changes as dev with:

```
.venv/bin/python -m spotifixed diff '<playlist>'
```

and summarize: added, removed (they keep their files and settings), under a
new ID (settings and cached files were carried across automatically), and
changed details, noting any turned-off or offset tracks it lists. If anything
was added, run `sync '<playlist>'` as dev to fetch it (no token needed), then
report as in Step 3.

## Constraints

- Never read, ask for, or handle the Apify token.
- Don't edit anything under `cache/` or `state/` by hand.
