#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- spotifixed: play a cached Spotify playlist through mpv with a lyric overlay ---
# The tool is split by what needs Ethan's session, and this step wires up both halves:
#   dev side  (no deploy at all): `sync`, `status`, `pin` run from the repo's own .venv
#             as dev, reached through the spotifixed-sync launcher (ethan-bin).
#   shared    the repo's cache/ and state/ directories: dev fills the cache, the daemon
#             (as ethan) reads it and writes per-track lyric offsets into state. Both
#             are made group `developers`, setgid and group-writable here; the tool
#             itself forces no permissions, and both launchers run with umask 002.
#   ethan side(review-gated vs spotifixed's approved upstream): a COPY of the
#             spotifixed/ package under ~/.local/share/spotifixed, run by the
#             system python3 through the spotifixed launcher (ethan-bin). mpv needs
#             Ethan's audio and the overlay needs his display, and dev can reach neither.
# The package uses only the standard library for the ethan-side commands, so there is
# no virtualenv and nothing pip-installed on this side.
#
# The launchers and ~/.config/spotifixed/settings.conf are ordinary files of THIS
# repo, deployed by ethan-bin and ethan-config. See common.sh for SPOTIFIXED_REPO /
# SPOTIFIXED_BASE_REF, review_gate_commit_in and deploy_tree_from_commit.
PACKAGE="spotifixed"

# One-time migration from the tool's old name, playlist-player (renamed 2026-10).
# Removes what the old name deployed. The hand-maintained secrets.env is never touched
# by an installer: while it is still in the old dir, that dir stays and Ethan is told
# the one command to move it. A no-op once nothing old is left.
migrate_from_playlist_player() {
    local old_cfg="$ETHAN_HOME/.config/playlist-player"
    if [ -f "$old_cfg/secrets.env" ]; then
        warn "spotifixed: secrets.env is still under the old name; move it, then re-run install.sh:"
        warn "   mv ~/.config/playlist-player/secrets.env ~/.config/spotifixed/secrets.env"
    else
        rm -rf "$old_cfg"
    fi
    local old
    for old in \
        "$ETHAN_HOME/.local/share/playlist-player" \
        "$ETHAN_HOME/.local/bin/playlist-player" \
        "$ETHAN_HOME/.local/bin/playlist-player-sync" \
        "$ETHAN_HOME/.local/bin/playlist-player.run.sh" \
        "$ETHAN_HOME/.local/share/applications/playlist-player.desktop" \
        "$ETHAN_HOME/Desktop/playlist-player.desktop"; do
        [ -e "$old" ] || continue
        rm -rf "$old"
        say "spotifixed: removed old ${old#"$ETHAN_HOME"/}"
    done
}

deploy_spotifixed() {
    local repo="$SPOTIFIXED_REPO"
    local app="$ETHAN_HOME/.local/share/spotifixed"
    [ -d "$repo/$PACKAGE" ] || { say "spotifixed: no $repo/$PACKAGE — skipping"; return; }

    # ---- shared data directories ----
    # Created as dev (the repo is dev-writable; state/ may not exist before the first
    # offset is saved). Whoever owns each one sets the mode, so try both accounts.
    local d
    for d in cache state; do
        as_dev mkdir -p "$repo/$d"
        [ "$(stat -c '%a %G' "$repo/$d")" = "2775 developers" ] && continue
        chgrp developers "$repo/$d" 2>/dev/null || as_dev chgrp developers "$repo/$d" 2>/dev/null || true
        chmod 2775 "$repo/$d" 2>/dev/null || as_dev chmod 2775 "$repo/$d" 2>/dev/null \
            || warn "spotifixed: could not make $repo/$d group-writable and setgid"
    done
    say "spotifixed: shared cache/ and state/ ready under $repo"

    # ---- ethan side: one review-gated copy of the package AS COMMITTED ----
    # Deployed from one commit, never the working tree (see review_gate_commit_in):
    # an uncommitted edit is reported and left out, so the copy is always a state
    # of the package that existed as a whole.
    review_gate_commit_in "$repo" "$SPOTIFIXED_BASE_REF" "$PACKAGE" \
        || { say "   skipped the spotifixed package"; return; }

    local count
    if ! count="$(deploy_tree_from_commit "$repo" "$GATED_COMMIT" "$PACKAGE" "$app")"; then
        warn "spotifixed: could not extract $PACKAGE from ${GATED_COMMIT:0:12} — the old copy is left in place"
        return
    fi
    chmod 0755 "$app"
    say "ethan-tier: installed $count files to $app/$PACKAGE (commit ${GATED_COMMIT:0:12})"

    # The copy must work on the bare system interpreter; say so now rather than at
    # first use if it does not.
    local version
    if version="$(cd "$app" && /usr/bin/python3 -s -m "$PACKAGE" --version 2>&1)"; then
        say "ethan-tier: spotifixed $version runs on the system python3"
    else
        warn "spotifixed: the deployed copy does not start: $version"
    fi

    [ -e "$ETHAN_HOME/.config/spotifixed/secrets.env" ] \
        || say "   note: no ~/.config/spotifixed/secrets.env yet (only needed to fetch a NEW playlist; see $repo/secrets.env.example)"
}
migrate_from_playlist_player
deploy_spotifixed
