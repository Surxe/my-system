---
name: add-playlist
description: >-
  Add a Spotify playlist to spotifixed: check whether it is already cached,
  hand Ethan the one sync command that needs his Apify token, then report what
  landed and what needs a hand-picked audio. Use whenever Ethan wants to add,
  fetch, or sync a new playlist into spotifixed.
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
  so; if Ethan wants it refreshed or completed, run
  `.venv/bin/python -m spotifixed sync '<playlist>'` yourself (it is
  resumable). Fetching the track list again (`--refresh-tracklist`) is a paid
  run and needs the token, so that one goes to Ethan as in Step 2.

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

## Constraints

- Never read, ask for, or handle the Apify token.
- Don't edit anything under `cache/` or `state/` by hand.
