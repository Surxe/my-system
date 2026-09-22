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

# Neutral agent root + the DeepSeek Harness home. Shared content (skills, memory,
# the box's global AGENTS.md) lives in ~/.agents; Claude Code reads it through
# symlinks (ensure_agents_symlink below), the DeepSeek Harness reads skills from
# ~/.agents/skills natively and memory through the `memory-standard` plugin rooted
# at $DSH_HOME_DIR/memory.
AGENTS_DIR="$DEV_HOME/.agents"
CLAUDE_DIR="$DEV_HOME/.claude"
DSH_HOME_DIR="$DEV_HOME/.dsh"
DEV_ENV_REPO="$REPO_ROOT/../dev-env"

say(){ printf '%s\n' "$*"; }

# warn: emit a NON-FATAL problem. Prints inline (with a "!!" marker) AND, when run
# under install.sh (which sets MYSYS_RUN_LOG), appends a structured
# "<step>\t<message>" record so the orchestrator can replay every warning in its
# end-of-run summary — otherwise a warning buried deep in a ~25-step deploy scrolls
# away unseen. STEP_NAME is set by the orchestrator per step; a standalone installer
# run leaves it unset (-> "?") and, with no MYSYS_RUN_LOG, warn() degrades to a
# plain inline say. Always returns 0 so a caller's `set -e` never trips on it.
warn(){
    say "!! $*"
    if [ -n "${MYSYS_RUN_LOG:-}" ]; then
        printf '%s\t%s\n' "${STEP_NAME:-?}" "$*" >>"$MYSYS_RUN_LOG" 2>/dev/null || true
    fi
    return 0
}

# as_dev: run a command as dev (or noop if already dev). Used by dev-tier installers.
as_dev() { if [ "$ME" = dev ]; then "$@"; else sudo -u dev "$@"; fi; }

# ensure_agents_symlink: point a live ~/.claude/~/.dsh path at a neutral
# ~/.agents target (idempotent; a pre-existing real file/dir is moved aside to
# <path>.pre-agents rather than deleted, so the old copy-into-~/.claude layout is
# migrated without data loss).
ensure_agents_symlink() {   # $1 = target (must exist), $2 = link path
    local target="$1" link="$2"
    [ -e "$target" ] || [ -L "$target" ] || { say "symlink: target missing: $target"; return 1; }
    if [ -L "$link" ]; then
        [ "$(readlink "$link")" = "$target" ] && return 0
        rm -f "$link"
    elif [ -e "$link" ]; then
        local bak="$link.pre-agents"
        rm -rf "$bak"
        mv "$link" "$bak"
        say "symlink: moved existing $link -> $bak"
    fi
    mkdir -p "$(dirname "$link")"
    ln -s "$target" "$link"
    say "symlink: $link -> $target"
}

# The ethan-approved baseline to diff privileged files against: the current
# branch's upstream, else origin/HEAD's default branch, else a sane fallback.
# (Works whether the repo's default branch is `main` or `master`.)
BASE_REF="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[ -n "$BASE_REF" ] || BASE_REF="$(git -C "$REPO_ROOT" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
[ -n "$BASE_REF" ] || BASE_REF="origin/master"

# --- fetch memo: refresh a repo's origin at most ONCE per process, so a per-file
#     review gate over N files costs one fetch, not N (each fetch is a network
#     round trip). When install.sh pre-fetches every gated repo for the whole run
#     it exports MYSYS_NO_FETCH=1, and children skip the fetch entirely. A
#     standalone installer run (no MYSYS_NO_FETCH) still self-fetches, once. ---
declare -A _FETCHED_REPOS
ensure_fetched() {   # $1 = repo root
    local root="$1"
    [ "${MYSYS_NO_FETCH:-0}" = 1 ] && return 0   # a parent already fetched this run
    [ -n "${_FETCHED_REPOS[$root]:-}" ] && return 0
    git -C "$root" fetch -q origin 2>/dev/null || true
    _FETCHED_REPOS[$root]=1
}

# --- review gate: a privileged file must match its repo's approved upstream,
#     else prompt. review_gate_in() is generic over the repo (used for the
#     cross-repo todo bin); review_gate() binds it to THIS repo. ---
review_gate_in() {   # $1 = repo root, $2 = base ref, $3 = repo-relative path
    local root="$1" base="$2" rel="$3"
    ensure_fetched "$root"
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

# The DATA store is a separate repo (owner dev, group `developers`, group-writable).
# Because ethan is not its owner, git refuses ops there ("dubious ownership") unless
# the store is in ethan's git `safe.directory` — without it every ethan-side `todo`
# git op (commit on capture/done, the read/classify rebase-pull) fails silently and
# leaves the tree dirty, which then blocks the next pull. The todo installers assert
# safe.directory for the running user (ensure_safe_dir) to close that.
TODO_STORE="/srv/dev/repos/todo-store"

# ensure_safe_dir: idempotently add a path to the CURRENT user's global git
# safe.directory (git has no dedup on --add, so guard first). No-op if already set.
ensure_safe_dir() {   # $1 = absolute repo path
    local path="$1"
    git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$path" && return 0
    git config --global --add safe.directory "$path"
}

# --- claude-tts: spoken Claude output. Like `todo`, it lives in its OWN repo and
# is deployed cross-repo: dev's own files (tts CLI, narrate.py) copied ungated, but
# ethan-side files (tts-speak + the systemd user units) are review-gated against
# claude-tts's approved upstream before they land in ethan's home. ---
CLAUDE_TTS_REPO="/srv/dev/repos/claude-tts"
CLAUDE_TTS_BASE_REF="$(git -C "$CLAUDE_TTS_REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo origin/main)"

# --- timing helpers (used by install.sh's --debug per-step timing) ---
# now_ms: current wall-clock time in integer milliseconds (bash 5 EPOCHREALTIME,
# e.g. 1787184304.870728 -> seconds*1000 + microseconds/1000). fmt_dur: render an
# integer millisecond count as a "S.mmm s" duration for human-readable output.
now_ms(){ printf '%d' $(( ${EPOCHREALTIME%.*} * 1000 + 10#${EPOCHREALTIME#*.} / 1000 )); }
fmt_dur(){ printf '%d.%03ds' "$(( $1 / 1000 ))" "$(( $1 % 1000 ))"; }
