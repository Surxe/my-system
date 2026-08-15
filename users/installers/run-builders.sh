#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- build phase: regenerate all per-user artifacts (dev's CLAUDE.md, etc.) via
#     users/build.sh. Run AS dev so generated files stay dev-owned (shared-file
#     convention), and so a deploy always ships fresh artifacts, not stale ones. ---
run_builders() {
    local runner="$REPO_ROOT/users/build.sh"
    [ -x "$runner" ] || { say "build: no executable $runner — skipping"; return; }
    say "== build: regenerating users/ artifacts (build.sh) =="
    if [ "$ME" = dev ]; then
        "$runner"
    else
        sudo -u dev "$runner"
    fi
}
run_builders
