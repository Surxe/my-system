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
#   dev-tier    users/dev/CLAUDE.md      -> ~dev/.claude/CLAUDE.md     (copy; dev's own file)
#               users/dev/skills/*       -> ~dev/.claude/skills/*      (copy; dev's own files)
#               users/dev/memory/<proj>/* -> ~dev/.claude/projects/-<proj>/memory/* (copy; dev's own files)
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

# Ordered deploy steps (basenames under installers/). This array IS the canonical
# run order; dependencies are filesystem-based, so order matters:
#   - run-builders first, so freshly-built artifacts ship;
#   - todo-ethan before ethan-bin (todo-capture delegates to the deployed todo);
#   - desktop-entries before ethan-shortcuts (hotkeys bind to deployed .desktops).
INSTALLERS=(
  run-builders             # regenerate artifacts before shipping them
  root-tier                # host scripts + sudoers drop-ins (sudo)
  ethan-bashrc             # ethan's .bashrc.d modules
  todo-ethan               # reviewed todo bin -> ethan's ~/.local/bin (before todo-capture)
  ethan-bin                # PATH executables (todo-capture) -> ethan's ~/.local/bin
  ethan-config             # ~/.config trees (fastfetch, systemd units, ...) -> ethan's ~/.config
  steam-tracker            # steam-price-tracker: ensure SMTP secret + enable resume watcher
  desktop-entries          # .desktop launchers -> ethan's menu + desktop
  ethan-shortcuts          # global hotkeys -> ~ethan/.config/kglobalshortcutsrc
  ethan-taskbar-launchers  # per-monitor taskbar pins -> live plasmashell
  dev-claude-md            # dev's CLAUDE.md via sudo -u dev
  dev-skills               # dev's ~/.claude/skills via sudo -u dev
  dev-memory               # dev's ~/.claude Claude memory via sudo -u dev
  dev-bashrc               # dev's ~/.bashrc.d fragments (cc alias) via sudo -u dev
  dev-statusline           # dev's ~/.claude status line + wires settings.json
  todo-dev                 # copies todo/bin/todo -> dev's ~/.local/bin via sudo -u dev
)

case "$ME" in
    ethan|root)
        say "== deploy (operator: $ME) =="
        for name in "${INSTALLERS[@]}"; do
            bash "$SCRIPT_DIR/installers/$name.sh"
        done
        ;;
    *)
        say "install.sh must be run as ethan (it deploys privileged files)." >&2
        say "current user: '$ME' — refusing." >&2
        exit 1 ;;
esac
say "== done =="
