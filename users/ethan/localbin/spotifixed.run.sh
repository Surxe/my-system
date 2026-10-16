#!/usr/bin/env bash
# HAND-MAINTAINED (do not regenerate via add-shortcut).
# "Spotifixed" launcher: the terminal that IS the application. It runs
# `spotifixed start` (daemon + lyric overlay + the page in the browser) in the
# foreground, so the window stays for as long as the player runs and the two end
# together: closing the window stops the player (the daemon saves its place and takes
# mpv and the overlay down on the hangup), and Ctrl-C closes the window.
#
# The window is held open only when start FAILED, so the reason can be read. A clean
# stop, or a second click while it is already running (which just opens the page),
# closes by itself.
# Deployed (COPIED, review-gated) into ethan's ~/.local/bin by install.sh.
set -uo pipefail

"$HOME/.local/bin/spotifixed" start "$@"
status=$?
if [ "$status" -ne 0 ] && [ -t 0 ]; then
  echo
  read -n1 -rp "spotifixed stopped with an error (exit $status). Press any key to close…"
  echo
fi
exit "$status"
