#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- playlist-player: play a cached Spotify playlist through mpv with a lyric overlay ---
# The tool is split by what needs Ethan's session, and this step wires up both halves:
#   dev side  (no deploy at all): `sync`, `status`, `pin` run from the repo's own .venv
#             as dev, reached through the playlist-player-sync launcher (ethan-bin).
#   shared    the repo's cache/ and state/ directories: dev fills the cache, the daemon
#             (as ethan) reads it and writes per-track lyric offsets into state. Both
#             are made group `developers`, setgid and group-writable here; the tool
#             itself forces no permissions, and both launchers run with umask 002.
#   ethan side(review-gated vs playlist-player's approved upstream): a COPY of the
#             playlist_player/ package under ~/.local/share/playlist-player, run by the
#             system python3 through the playlist-player launcher (ethan-bin). mpv needs
#             Ethan's audio and the overlay needs his display, and dev can reach neither.
# The package uses only the standard library for the ethan-side commands, so there is
# no virtualenv and nothing pip-installed on this side.
#
# The launchers and ~/.config/playlist-player/settings.conf are ordinary files of THIS
# repo, deployed by ethan-bin and ethan-config. See common.sh for PLAYLIST_PLAYER_REPO /
# PLAYLIST_PLAYER_BASE_REF and review_gate_tree_in.
PACKAGE="playlist_player"

deploy_playlist_player() {
    local repo="$PLAYLIST_PLAYER_REPO"
    local app="$ETHAN_HOME/.local/share/playlist-player"
    [ -d "$repo/$PACKAGE" ] || { say "playlist-player: no $repo/$PACKAGE — skipping"; return; }

    # ---- shared data directories ----
    # Created as dev (the repo is dev-writable; state/ may not exist before the first
    # offset is saved). Whoever owns each one sets the mode, so try both accounts.
    local d
    for d in cache state; do
        as_dev mkdir -p "$repo/$d"
        [ "$(stat -c '%a %G' "$repo/$d")" = "2775 developers" ] && continue
        chgrp developers "$repo/$d" 2>/dev/null || as_dev chgrp developers "$repo/$d" 2>/dev/null || true
        chmod 2775 "$repo/$d" 2>/dev/null || as_dev chmod 2775 "$repo/$d" 2>/dev/null \
            || warn "playlist-player: could not make $repo/$d group-writable and setgid"
    done
    say "playlist-player: shared cache/ and state/ ready under $repo"

    # ---- ethan side: one review-gated copy of the package's TRACKED files ----
    # Tracked files only: the gate works on a git diff, and an untracked file dropped
    # into the working tree would be in no diff, so it must not be deployed either.
    review_gate_tree_in "$repo" "$PLAYLIST_PLAYER_BASE_REF" "$PACKAGE" \
        || { say "   skipped the playlist-player package"; return; }

    local staging rel count=0
    install -d -m 0755 "$app"
    staging="$(mktemp -d "$app/.staging.XXXXXX")"
    while IFS= read -r -d '' rel; do
        [ -f "$repo/$rel" ] || continue   # tracked but deleted locally: nothing to copy
        install -D -m 0644 "$repo/$rel" "$staging/$rel"
        count=$((count + 1))
    done < <(git -C "$repo" ls-files -z -- "$PACKAGE")
    if [ "$count" -eq 0 ]; then
        rm -rf "$staging"
        warn "playlist-player: git listed no files under $repo/$PACKAGE — nothing deployed"
        return
    fi
    # Replace the old copy wholesale, so a file removed upstream does not linger.
    rm -rf "${app:?}/$PACKAGE"
    mv "$staging/$PACKAGE" "$app/$PACKAGE"
    rm -rf "$staging"
    chmod 0755 "$app" "$app/$PACKAGE"
    say "ethan-tier: installed $count files to $app/$PACKAGE"

    # The copy must work on the bare system interpreter; say so now rather than at
    # first use if it does not.
    local version
    if version="$(cd "$app" && /usr/bin/python3 -s -m "$PACKAGE" --version 2>&1)"; then
        say "ethan-tier: playlist-player $version runs on the system python3"
    else
        warn "playlist-player: the deployed copy does not start: $version"
    fi

    [ -e "$ETHAN_HOME/.config/playlist-player/secrets.env" ] \
        || say "   note: no ~/.config/playlist-player/secrets.env yet (only needed to fetch a NEW playlist; see $repo/secrets.env.example)"
}
deploy_playlist_player
