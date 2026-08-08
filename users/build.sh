#!/usr/bin/env bash
#
# build.sh — regenerate every generated per-user artifact under users/ (files
# assembled from blueprints/generators rather than hand-edited).
#
# Currently that's dev's CLAUDE.md (dev/build-claude-md.sh). Add new per-user
# builders to the BUILDERS list below; each must be an idempotent, standalone
# script that regenerates its own artifact.
#
# Safe to run anytime as either `dev` or `ethan`. install.sh calls this (as dev)
# before deploying, so a deploy always ships freshly-built artifacts.
set -euo pipefail

USERS_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # .../users

BUILDERS=(
  "$USERS_DIR/dev/build-claude-md.sh"
)

echo "== build.sh: regenerating users/ artifacts =="
for b in "${BUILDERS[@]}"; do
  [ -x "$b" ] || { echo "error: builder not executable: $b" >&2; exit 1; }
  echo "-> $(basename "$b")"
  "$b"
done
echo "== build.sh: done =="
