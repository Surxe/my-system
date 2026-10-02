#!/usr/bin/env bash
#
# build-claude-md.sh  —  MASTER build script for dev's CLAUDE.md
#
# A thin hookpoint: the build itself is the shared engine in the sibling dev-env
# repo (dev-env/lib/build-agents-md.sh), which both machine repos use. It:
#   1. Regenerates the generated sections the blueprint uses — {{repo-descriptions}},
#      the repos cloned under /srv/dev/repos on THIS box — into sections/.
#   2. Assembles CLAUDE.md from CLAUDE.md.blueprint, replacing each whole-line
#      {{token}} with sections/<token>.md from this dir, else from dev-env's
#      sections/ (the SHARED sections, e.g. {{shared}}, identical on every box).
#
# The resulting CLAUDE.md is installed (copied) to ~/.agents/AGENTS.md by
# users/installers/dev-claude-md.sh, which symlinks ~/.claude/CLAUDE.md and
# ~/.dsh/AGENTS.md to it (Claude Code + DeepSeek Harness global instructions).
#
# If the dev-env clone (or its builder) is missing, this warns and keeps the last
# committed CLAUDE.md rather than failing the deploy.
#
#   ./build-claude-md.sh [--force]   # --force re-fetches every repo description

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DEV_ENV_REPO="$(cd "$REPO_ROOT/../../.." && pwd)/dev-env"
BUILDER="$DEV_ENV_REPO/lib/build-agents-md.sh"

if [ ! -x "$BUILDER" ]; then
  echo "warning: no dev-env builder at $BUILDER — keeping the last built $REPO_ROOT/CLAUDE.md" >&2
  exit 0
fi

exec "$BUILDER" \
  --blueprint "$REPO_ROOT/CLAUDE.md.blueprint" \
  --sections  "$REPO_ROOT/sections" \
  --out       "$REPO_ROOT/CLAUDE.md" \
  --cache     "$REPO_ROOT/.cache" \
  "$@"
