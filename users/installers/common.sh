#!/usr/bin/env bash
#
# common.sh — shared library for install.sh and every users/installers/*.sh step.
#
# SOURCED, never executed: it provides the deploy environment (REPO_ROOT, ME, the
# user homes, the diff baseline) plus the shared helpers (say, the review gate) and
# the cross-repo `todo` locations. Both install.sh and each standalone installer
# `source` this file, so it derives its paths from its OWN location (BASH_SOURCE),
# not "$0", and it must NOT set -euo pipefail (a sourced lib must not mutate the
# caller's shell options — each standalone script sets that itself).

# Guard against double-source (harmless, but keeps env derivation to once).
[ -n "${_MYSYSTEM_COMMON_SOURCED:-}" ] && return 0
_MYSYSTEM_COMMON_SOURCED=1

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../users/installers
REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"
ME="$(id -un)"
DEV_HOME="$(getent passwd dev   | cut -d: -f6)"
ETHAN_HOME="$(getent passwd ethan | cut -d: -f6)"

say(){ printf '%s\n' "$*"; }

# The ethan-approved baseline to diff privileged files against: the current
# branch's upstream, else origin/HEAD's default branch, else a sane fallback.
# (Works whether the repo's default branch is `main` or `master`.)
BASE_REF="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[ -n "$BASE_REF" ] || BASE_REF="$(git -C "$REPO_ROOT" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
[ -n "$BASE_REF" ] || BASE_REF="origin/master"

# --- review gate: a privileged file must match its repo's approved upstream,
#     else prompt. review_gate_in() is generic over the repo (used for the
#     cross-repo todo bin); review_gate() binds it to THIS repo. ---
review_gate_in() {   # $1 = repo root, $2 = base ref, $3 = repo-relative path
    local root="$1" base="$2" rel="$3"
    git -C "$root" fetch -q origin 2>/dev/null || true
    if git -C "$root" rev-parse --verify -q "$base" >/dev/null; then
        if git -C "$root" diff --quiet "$base" -- "$rel"; then
            return 0   # matches ethan-approved upstream — no prompt needed
        fi
        say "!! '$rel' ($root) DIFFERS from approved $base:"
        git -C "$root" --no-pager diff "$base" -- "$rel" || true
    else
        say "!! no upstream ($base) to compare against yet: '$rel' ($root)"
    fi
    local a; read -r -p "   install this privileged file anyway? [y/N] " a </dev/tty
    [ "$a" = y ] || [ "$a" = Y ]
}

review_gate() {   # $1 = THIS repo's relative path
    review_gate_in "$REPO_ROOT" "$BASE_REF" "$1"
}

# --- todo tool: shared locations for the cross-repo `todo` CLI (deployed onto each
#     user's PATH by the todo-dev / todo-ethan installers). The tool lives in its
#     OWN repo; its store is shared (group `developers`, group-writable) and bin/todo
#     is generic — the one dev-only command, `classify`, self-guards — so the same
#     bin serves both users. Deployed as a COPY (never a symlink into the dev-writable
#     tree). For ethan it is review-gated against the TODO repo's own approved
#     upstream (cross-repo gate). ---
TODO_REPO="/srv/dev/repos/todo"
TODO_BIN="$TODO_REPO/bin/todo"
TODO_BASE_REF="$(git -C "$TODO_REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo origin/master)"
