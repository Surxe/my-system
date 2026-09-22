#!/usr/bin/env bash
#
# install.sh — deploy this repo's per-user + host config to their live locations.
#
# This is a thin ORCHESTRATOR: the shared deploy environment + helpers live in
# installers/common.sh, and each deploy step is its own standalone, individually
# runnable script under installers/. install.sh sources common.sh, guards the
# operator, and runs the installers below in order. First step (run-builders)
# regenerates all per-user artifacts (dev's CLAUDE.md, etc.) so a deploy always
# ships freshly-built files. Each installer names its tier in its output.
#
# Tiers, by trust level:
#   dev-tier    users/dev/CLAUDE.md      -> ~dev/.agents/AGENTS.md     (copy; symlinked to ~dev/.claude/CLAUDE.md + ~dev/.dsh/AGENTS.md)
#               users/dev/skills/*       -> ~dev/.agents/skills/*      (copy; symlinked to ~dev/.claude/skills; dsh reads ~/.agents/skills)
#               users/dev/memory/<proj>/* -> ~dev/.agents/memory/* + ~dev/.dsh/memory/* (copy; Claude via symlink, dsh via memory-standard)
#               users/dev/mcp/*.json     -> dev's Claude MCP servers    (claude mcp reconcile; dev's own config)
#               users/dev/localbin/*     -> ~dev/.local/bin/*          (copy, 0755; on PATH)
#               users/dev/.bashrc.d/*    -> ~dev/.bashrc.d/*           (copy; box-specific, additive alongside dev-env's)
#               (git identity)           -> ~dev/.gitconfig user.*     (git config --global; commits credit Surxe)
#               (cross-repo) todo/bin/todo -> ~dev/.local/bin/todo     (copy; dev's own home)
#   ethan-tier  users/ethan/.bashrc.d/*  -> ~ethan/.bashrc.d/*         (copy; runs AS ethan)
#               users/ethan/localbin/*   -> ~ethan/.local/bin/*        (copy, 0755; on PATH)
#               (cross-repo) todo/bin/todo -> ~ethan/.local/bin/todo   (copy, 0755; gated vs todo's origin/master)
#               users/ethan/desktop-entries/*.desktop
#                                        -> ~ethan/.local/share/applications/*  (menu, 0644)
#                                        +  ~ethan/Desktop/*                     (icon, 0755)
#               users/ethan/.config/**   -> ~ethan/.config/**          (copy 0644; e.g. fastfetch)
#               users/ethan/kde-global-shortcuts.conf
#                                        -> ~ethan/.config/kglobalshortcutsrc   (per-key merge)
#   root-tier   system/usr-local-sbin/*  -> /usr/local/sbin/*          (sudo install, 0755)
#               system/etc-sudoers.d/*   -> /etc/sudoers.d/*           (sudo install, 0440 + visudo -c)
#
# Debug/timing: pass --debug (or set MYSYS_DEBUG=1) to time each deploy step and
# print a "slowest first" summary at the end. Timing is measured at THIS orchestrator
# level (wall-clock around each installers/*.sh), so it covers every step uniformly
# without touching the individual, standalone-runnable installers. Use it to spot
# which steps dominate a deploy before optimizing them.
#
# Operator: must be run as ethan (or root). It deploys all three tiers, including
# dev's CLAUDE.md (written via sudo -u dev). Refuses for any other user. (This
# guard, plus sudo + ethan's private home, is the real boundary — file-exec perms
# in this dev-writable repo are not, since dev could `bash install.sh` regardless.)
#
# SECURITY NOTE (deliberate trade-off): privileged files are deployed by COPY from
# the local WORKING TREE, which is dev-writable. A local edit to an ethan/root file
# therefore reaches ethan/root on the next deploy — the GitHub merge gate does NOT
# cover local tampering. Mitigation: every privileged file is diffed against the
# ethan-approved `origin/master` and requires explicit confirmation before install
# (the "review gate" in common.sh). This narrows, but does not close, that window.
# Note the review gate covers each DEPLOYED file; it does not cover install.sh nor
# these installers/*.sh themselves (unchanged from when this was one monolith). See
# development/git-workflow.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # .../users
source "$SCRIPT_DIR/installers/common.sh"

# --- args: --debug (or MYSYS_DEBUG=1) enables per-step timing. ---
DEBUG="${MYSYS_DEBUG:-0}"
for arg in "$@"; do
    case "$arg" in
        --debug|-d) DEBUG=1 ;;
        *) say "install.sh: unknown argument '$arg' (supported: --debug)" >&2; exit 2 ;;
    esac
done

# Ordered deploy steps (basenames under installers/). This array IS the canonical
# run order; dependencies are filesystem-based, so order matters:
#   - run-builders first, so freshly-built artifacts ship;
#   - todo-ethan before ethan-bin (todo-capture delegates to the deployed todo);
#   - desktop-entries before ethan-shortcuts (hotkeys bind to deployed .desktops).
INSTALLERS=(
  run-builders             # regenerate artifacts before shipping them
  root-tier                # host scripts + sudoers drop-ins (sudo)
  ethan-bashrc             # ethan's .bashrc.d modules
  ethan-ssh                # ethan's SSH config + keys for todo-hub (before todo-ethan/sync)
  todo-ethan               # reviewed todo bin -> ethan's ~/.local/bin (before todo-capture)
  ethan-bin                # PATH executables (todo-capture) -> ethan's ~/.local/bin
  ethan-config             # ~/.config trees (fastfetch, systemd units, ...) -> ethan's ~/.config
  clip-discord             # clip-db: create Discord post spool + enable queue watcher
  claude-tts               # spoken Claude output: dev tts CLI + piper, ethan player + spool + watchers
  desktop-entries          # .desktop launchers -> ethan's menu + desktop
  ethan-shortcuts          # global hotkeys -> ~ethan/.config/kglobalshortcutsrc
  ethan-plasmarc           # plasmarc tweaks (tooltip delay) -> ~ethan/.config/plasmarc
  ethan-plasmoids          # local Plasma widgets (launcher-group) -> ethan's ~/.local/share
  ethan-taskbar-groups     # assert launcher-group + minimized-TM config from conf
  dev-claude-md            # dev's global instructions -> ~dev/.agents/AGENTS.md (+ ~/.claude/CLAUDE.md, ~/.dsh/AGENTS.md symlinks)
  dev-skills               # dev's box-local skills -> ~dev/.agents/skills (symlinked into ~/.claude/skills; dsh reads natively)
  dev-memory               # dev's box-local memory -> ~dev/.agents/memory + ~dev/.dsh/memory (Claude + DeepSeek Harness)
  dev-env-layer            # shared dev config layer (skills, cc/ds, statusline, memories, dsh plugin) from ../dev-env
  dev-bashrc               # dev's box-specific .bashrc.d modules (todo sync, hs) -> ~dev/.bashrc.d
  dev-mcp                  # dev's Claude MCP servers (reconcile from users/dev/mcp/*.json)
  dev-ssh                  # copy ethan's todo/home-server SSH config + key into dev's ~/.ssh
  dev-bin                  # dev's PATH executables (new) -> ~dev/.local/bin via sudo -u dev
  todo-dev                 # copies todo/bin/todo -> dev's ~/.local/bin via sudo -u dev
  dev-todo-sync            # dev's todo hub sync: user path/service + 'hub' remote + linger
)

case "$ME" in
    ethan|root)
        [ "$DEBUG" = 1 ] && _dbg=" [debug: step timing on]" || _dbg=""
        say "== deploy (operator: $ME)$_dbg =="

        # Run-log: a shared file each step's warn() appends "<step>\t<message>"
        # records to, so a non-fatal warning emitted deep in a child installer (its
        # own subprocess — an in-memory list can't reach us) can be replayed in the
        # end-of-run summary instead of scrolling away. Exported so every
        # installers/*.sh inherits it; removed on exit.
        MYSYS_RUN_LOG="$(mktemp "${TMPDIR:-/tmp}/mysys-install.XXXXXX")"
        export MYSYS_RUN_LOG
        trap 'rm -f "$MYSYS_RUN_LOG"' EXIT

        # Pre-fetch each review-gated repo's origin ONCE for the whole run, then tell
        # children to skip their own fetch (MYSYS_NO_FETCH). Previously every per-file
        # review gate fetched, so N gated files cost N network round trips per step.
        git -C "$REPO_ROOT" fetch -q origin 2>/dev/null || true
        git -C "$TODO_REPO" fetch -q origin 2>/dev/null || true
        git -C "$CLAUDE_TTS_REPO" fetch -q origin 2>/dev/null || true
        export MYSYS_NO_FETCH=1

        STEP_NAMES=(); STEP_MS=(); FAILED=()
        for name in "${INSTALLERS[@]}"; do
            export STEP_NAME="$name"        # warn() tags its records with this
            _t0="$(now_ms)"
            # Per-installer failure isolation: a non-zero exit is RECORDED and the
            # deploy CONTINUES. The guarantee is per-installer, not per-command —
            # each installer's own `set -e` still stops it at its first hard error.
            # An `if` condition is set -e's standard exemption, so a failing step
            # never trips THIS orchestrator's set -e.
            if bash "$SCRIPT_DIR/installers/$name.sh"; then :; else
                rc=$?
                FAILED+=("$name (exit $rc)")
                say "!! step '$name' FAILED (exit $rc) — continuing"
            fi
            _dt="$(( $(now_ms) - _t0 ))"
            STEP_NAMES+=("$name"); STEP_MS+=("$_dt")
            [ "$DEBUG" = 1 ] && say "   [debug] $name: $(fmt_dur "$_dt")"
        done
        unset STEP_NAME

        if [ "$DEBUG" = 1 ]; then
            say ""
            say "== debug: step timings (slowest first) =="
            total_ms=0
            for i in "${!STEP_NAMES[@]}"; do
                total_ms="$(( total_ms + STEP_MS[i] ))"
            done
            for i in "${!STEP_NAMES[@]}"; do
                printf '%s\t%s\n' "${STEP_MS[i]}" "${STEP_NAMES[i]}"
            done | sort -rn | while IFS=$'\t' read -r ms nm; do
                printf '   %9s  %s\n' "$(fmt_dur "$ms")" "$nm"
            done
            printf '   %9s  %s\n' "$(fmt_dur "$total_ms")" "TOTAL"
        fi

        # --- end-of-run summary: replay every warning, then every failed step, so
        #     neither gets lost in a long deploy's scrollback. Exit non-zero if any
        #     step failed, so callers/automation can detect a partial deploy. ---
        if [ -s "$MYSYS_RUN_LOG" ]; then
            say ""
            say "== warnings ($(wc -l <"$MYSYS_RUN_LOG" | tr -d ' ')) =="
            while IFS=$'\t' read -r _step _msg; do
                printf '   [%s] %s\n' "$_step" "$_msg"
            done <"$MYSYS_RUN_LOG"
        fi
        if [ "${#FAILED[@]}" -gt 0 ]; then
            say ""
            say "== FAILED steps (${#FAILED[@]}) =="
            for f in "${FAILED[@]}"; do say "   $f"; done
            say "== done (with ${#FAILED[@]} failed step(s)) =="
            exit 1
        fi
        ;;
    *)
        say "install.sh must be run as ethan (it deploys privileged files)." >&2
        say "current user: '$ME' — refusing." >&2
        exit 1 ;;
esac
say "== done =="
