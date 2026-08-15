#!/usr/bin/env bash
#
# install.sh — deploy this repo's per-user + host config to their live locations.
#
# First runs the build phase (build.sh, as dev) to regenerate all per-user
# artifacts (dev's CLAUDE.md, etc.), so a deploy always ships freshly-built
# files. Then deploys the tiers below.
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
# (the "review gate" below). This narrows, but does not close, that window. See
# development/git-workflow.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # .../users
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
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

# --- build phase: regenerate all per-user artifacts (dev's CLAUDE.md, etc.) via
#     users/build.sh. Run AS dev so generated files stay dev-owned (shared-file
#     convention), and so a deploy always ships fresh artifacts, not stale ones. ---
run_builders() {
    local runner="$SCRIPT_DIR/build.sh"
    [ -x "$runner" ] || { say "build: no executable $runner — skipping"; return; }
    say "== build: regenerating users/ artifacts (build.sh) =="
    if [ "$ME" = dev ]; then
        "$runner"
    else
        sudo -u dev "$runner"
    fi
}

# --- dev-tier: dev's own CLAUDE.md (copied, not symlinked — dev already controls it) ---
deploy_dev_tier() {
    local src="$REPO_ROOT/users/dev/CLAUDE.md" dst="$DEV_HOME/.claude/CLAUDE.md"
    [ -e "$src" ] || { say "dev-tier: no $src (build phase / run.sh should have created it)"; return; }
    if [ "$ME" = dev ]; then
        install -D -m 0644 "$src" "$dst"
    else
        sudo -u dev install -D -m 0644 "$src" "$dst"
    fi
    say "dev-tier: installed (copy) $dst"
}

# --- dev-tier: dev's own Claude skills -> ~dev/.claude/skills (dev's own files) ---
deploy_dev_skills() {
    local src="$REPO_ROOT/users/dev/skills" dst="$DEV_HOME/.claude/skills"
    [ -d "$src" ] || { say "dev-skills: no $src — skipping"; return; }
    # Additive copy: refreshes/adds skills; does NOT prune skills deleted from the repo.
    if [ "$ME" = dev ]; then
        mkdir -p "$dst"; cp -a "$src/." "$dst/"
    else
        sudo -u dev mkdir -p "$dst"; sudo -u dev cp -a "$src/." "$dst/"
    fi
    say "dev-tier: installed skills -> $dst"
}

# --- dev-tier: dev's own Claude memory -> ~dev/.claude/projects/-<proj>/memory ---
# One subdir per Claude project under users/dev/memory/<proj>/; the live path
# dash-encodes the project's absolute path, so <proj> is that path with '/'->'-'
# and the leading dash dropped (srv-dev -> -srv-dev). Same trust model as dev's
# skills (dev's OWN home — no review gate). Additive copy: refreshes/adds memory
# files, does NOT prune ones deleted from the repo.
deploy_dev_memory() {
    local root="$REPO_ROOT/users/dev/memory" d name dst
    [ -d "$root" ] || { say "dev-memory: no $root — skipping"; return; }
    for d in "$root"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        dst="$DEV_HOME/.claude/projects/-$name/memory"
        if [ "$ME" = dev ]; then
            mkdir -p "$dst"; cp -a "$d." "$dst/"
        else
            sudo -u dev mkdir -p "$dst"; sudo -u dev cp -a "$d." "$dst/"
        fi
        say "dev-tier: installed memory ($name) -> $dst"
    done
}

# --- dev-tier: copy dev's own .bashrc.d modules into ~dev/.bashrc.d (dev's files) ---
# No review gate: these are dev's OWN files (dev already controls its home), same
# trust model as dev's CLAUDE.md/skills. Additive copy: refreshes/adds fragments;
# does NOT prune fragments deleted from the repo. Dev's ~/.bashrc must source
# ~/.bashrc.d/*.sh (one-time loader bootstrap; see users/dev/.bashrc.d/README.md).
deploy_dev_bashrc() {
    local src="$REPO_ROOT/users/dev/.bashrc.d" dst="$DEV_HOME/.bashrc.d" f
    [ -d "$src" ] || { say "dev-bashrc: no $src — skipping"; return; }
    for f in "$src"/*.sh; do
        [ -e "$f" ] || continue
        if [ "$ME" = dev ]; then
            install -D -m 0644 "$f" "$dst/$(basename "$f")"
        else
            sudo -u dev install -D -m 0644 "$f" "$dst/$(basename "$f")"
        fi
        say "dev-tier: installed $dst/$(basename "$f")"
    done
}

# --- dev-tier: deploy dev's Claude status line + wire it into settings.json ---
# Same trust model as dev's CLAUDE.md/skills (dev's OWN home), so no review gate.
# Copies statusline.py (never a symlink — dev-writable tree must not execute in
# dev's home except by explicit deploy), then idempotently sets settings.json's
# statusLine key WITHOUT disturbing other keys (model, effortLevel, theme, ...).
deploy_dev_statusline() {
    local src="$REPO_ROOT/users/dev/statusline.py" dst="$DEV_HOME/.claude/statusline.py"
    local settings="$DEV_HOME/.claude/settings.json"
    [ -e "$src" ] || { say "dev-statusline: no $src — skipping"; return; }

    local run=( )
    [ "$ME" = dev ] || run=( sudo -u dev )

    "${run[@]}" install -D -m 0644 "$src" "$dst"
    say "dev-tier: installed (copy) $dst"

    # Merge-only settings edit: read-or-{}, set statusLine, write back with indent.
    "${run[@]}" python3 - "$settings" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except (OSError, ValueError):
    data = {}
data["statusLine"] = {"type": "command", "command": "python3 ~/.claude/statusline.py"}
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    f.write(json.dumps(data, indent=2) + "\n")
PY
    say "dev-tier: wired statusLine -> $settings"

    # Verify the deployed bar renders (warn, don't fail the whole deploy).
    if "${run[@]}" python3 "$dst" --selftest >/dev/null 2>&1; then
        say "dev-tier: statusline self-test passed"
    else
        say "!! dev-tier: statusline self-test FAILED — check $dst"
    fi
}

# --- todo tool: deploy the shared `todo` CLI onto each user's PATH ---
# The tool lives in its OWN repo (below); its store is shared (group
# `developers`, group-writable) and bin/todo is generic — the one dev-only
# command, `classify`, self-guards — so the same bin serves both users. Deployed
# as a COPY (never a symlink into the dev-writable tree). For ethan it is
# review-gated against the TODO repo's own approved upstream (cross-repo gate).
TODO_REPO="/srv/dev/repos/todo"
TODO_BIN="$TODO_REPO/bin/todo"
TODO_BASE_REF="$(git -C "$TODO_REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo origin/master)"

# dev-tier: dev's own copy (dev controls its home — no gate).
deploy_todo_dev() {
    [ -e "$TODO_BIN" ] || { say "todo-dev: no $TODO_BIN — skipping"; return; }
    if [ "$ME" = dev ]; then
        install -D -m 0755 "$TODO_BIN" "$DEV_HOME/.local/bin/todo"
    else
        sudo -u dev install -D -m 0755 "$TODO_BIN" "$DEV_HOME/.local/bin/todo"
    fi
    say "dev-tier: installed $DEV_HOME/.local/bin/todo"
}

# ethan-tier: reviewed copy of the cross-repo todo bin -> ethan's ~/.local/bin
# (privileged). todo-capture delegates to this deployed `todo`, so deploy it first.
deploy_todo_ethan() {
    [ -e "$TODO_BIN" ] || { say "todo-ethan: no $TODO_BIN — skipping"; return; }
    review_gate_in "$TODO_REPO" "$TODO_BASE_REF" "bin/todo" || { say "   skipped todo"; return; }
    install -D -m 0755 "$TODO_BIN" "$ETHAN_HOME/.local/bin/todo"
    say "ethan-tier: installed $ETHAN_HOME/.local/bin/todo"
}

# --- ethan-tier: copy .bashrc.d modules into ethan's home (privileged) ---
deploy_ethan_tier() {
    local d="$ETHAN_HOME/.bashrc.d" f base rel
    for f in "$REPO_ROOT"/users/ethan/.bashrc.d/*.sh; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="users/ethan/.bashrc.d/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        install -D -m 0644 "$f" "$d/$base"
        say "ethan-tier: installed $d/$base"
    done
}

# --- ethan-tier: copy PATH executables into ethan's ~/.local/bin (privileged) ---
# For tools ethan runs directly (e.g. todo-capture). A COPY, never a symlink, so
# dev-writable working-tree code never executes as ethan except by explicit,
# review-gated deploy. ~/.local/bin is on ethan's PATH (Debian ~/.profile).
deploy_ethan_bin() {
    local d="$ETHAN_HOME/.local/bin" f base rel
    for f in "$REPO_ROOT"/users/ethan/localbin/*; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="users/ethan/localbin/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        install -D -m 0755 "$f" "$d/$base"
        say "ethan-tier: installed $d/$base"
    done
}

# --- ethan-tier: mirror declared ~/.config trees into ethan's home (privileged) ---
# For plain per-user config (e.g. fastfetch/config.jsonc). Copied 0644 (data, no
# exec bit) from the dev-writable tree, so each file is review-gated like every
# other ethan-tier file. Walks users/ethan/.config/** and mirrors the path under
# it into ~ethan/.config/**, preserving subdirs; additive (never prunes files
# ethan has but the repo doesn't). Skips *.example (tracked placeholders, e.g.
# devscaffold/token.example) which are not live config.
deploy_ethan_config() {
    local root="$REPO_ROOT/users/ethan/.config" f rel dest
    [ -d "$root" ] || return
    while IFS= read -r -d '' f; do
        case "$f" in *.example) continue ;; esac
        rel="users/ethan/.config/${f#"$root"/}"          # repo-relative, for the gate
        dest="$ETHAN_HOME/.config/${f#"$root"/}"         # live target, subdirs preserved
        review_gate "$rel" || { say "   skipped ${f#"$root"/}"; continue; }
        install -D -m 0644 "$f" "$dest"
        say "ethan-tier: installed $dest"
    done < <(find "$root" -type f -print0)
}

# --- ethan-tier: steam-price-tracker resume-refresh (secret + systemd wiring) ---
# The two systemd USER units (under users/ethan/.config/systemd/user) and the two
# PATH scripts (steam-price-refresh, steam-price-resume-watch) are already deployed
# by deploy_ethan_config / deploy_ethan_bin above. This step does the two things
# those generic copies can't:
#   (a) ensure the Ethan-owned SMTP secret exists WITHOUT ever storing it in this
#       repo. Created only if absent (never overwritten, never read/echoed), and
#       only when install.sh is run interactively AS ethan (his private chmod-600
#       file). The repo carries only smtp.env.example.
#   (b) reload + enable the resume watcher in Ethan's user systemd.
deploy_steam_tracker() {
    local cfgdir="$ETHAN_HOME/.config/steam-price-tracker" env
    env="$cfgdir/smtp.env"
    local is_ethan=0; [ "$ME" = ethan ] && is_ethan=1
    local uid; uid="$(id -u ethan)"

    # (a) secret — presence check must run as ethan (dev cannot traverse his home).
    local present=0
    if [ "$is_ethan" = 1 ]; then
        [ -f "$env" ] && present=1
    else
        sudo -u ethan test -f "$env" && present=1
    fi

    if [ "$present" = 1 ]; then
        say "ethan-tier: steam smtp.env already present - leaving it untouched"
    elif [ "$is_ethan" = 1 ] && [ -t 0 ]; then
        say "ethan-tier: steam-price-tracker SMTP secret not found."
        local u p
        read -r -p "   Gmail sender address (blank = skip email setup): " u </dev/tty
        if [ -n "$u" ]; then
            read -r -s -p "   Gmail App Password (16 chars, hidden): " p </dev/tty; echo
            ( umask 077; mkdir -p "$cfgdir"
              printf 'STEAM_TRACKER_SMTP_USER=%s\nSTEAM_TRACKER_SMTP_PASSWORD=%s\n' "$u" "$p" > "$env" )
            chmod 600 "$env"
            say "   wrote $env (chmod 600)"
        else
            say "   skipped - email stays disabled until $env exists"
        fi
    else
        say "ethan-tier: steam smtp.env missing - run install.sh AS ethan in a"
        say "   terminal to enter it, or create $env by hand (chmod 600)."
    fi

    # (b) reload + enable the resume watcher in ethan's user systemd.
    if [ "$is_ethan" = 1 ]; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now steam-price-resume-watch.service \
            || say "!! could not enable steam-price-resume-watch.service"
    else
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload || true
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user \
            enable --now steam-price-resume-watch.service \
            || say "!! could not enable watcher as ethan (needs an active ethan session)"
    fi
    say "ethan-tier: steam-price-tracker resume watcher wired"
}

# --- ethan-tier: desktop launchers -> ethan's app menu + desktop (privileged) ---
# Each .desktop deploys to BOTH locations; only the .desktop is copied here.
# The Exec target for ethan-executed code must point at a DEPLOYED copy (e.g.
# ~/.local/bin, populated by deploy_ethan_bin) — never at the dev-writable repo
# tree, which would let a dev-tree edit run as ethan with no review gate. Only
# assets (Icon SVGs) and cross-repo runners are referenced in place by design.
deploy_desktop_entries() {
    local apps="$ETHAN_HOME/.local/share/applications" desk="$ETHAN_HOME/Desktop"
    local f base rel any=0
    for f in "$REPO_ROOT"/users/ethan/desktop-entries/*.desktop; do
        [ -e "$f" ] || continue
        any=1
        base="$(basename "$f")"; rel="users/ethan/desktop-entries/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        install -D -m 0644 "$f" "$apps/$base"   # menu entry (no exec bit / trust needed)
        install -D -m 0755 "$f" "$desk/$base"   # desktop icon (KDE needs the exec bit)
        say "ethan-tier: installed $base -> menu + desktop"
    done
    [ "$any" = 1 ] || return
    # Refresh KDE's menu cache so new entries appear without a re-login (best effort).
    if [ "$ME" = ethan ]; then
        kbuildsycoca6 >/dev/null 2>&1 || kbuildsycoca5 >/dev/null 2>&1 || true
    else
        sudo -u ethan kbuildsycoca6 >/dev/null 2>&1 || sudo -u ethan kbuildsycoca5 >/dev/null 2>&1 || true
    fi
}

# --- ethan-tier: assert declared KDE global shortcuts (privileged) ---
# Writes ONLY the [services][<id>] _launch keys listed in the conf, via
# kwriteconfig6 — merge-safe (every other shortcut untouched) and idempotent.
# Binds keys to already-deployed .desktop launchers, so run AFTER those. Takes
# effect on next login (a file write doesn't hot-reload kglobalaccel).
deploy_ethan_shortcuts() {
    local conf="$REPO_ROOT/users/ethan/kde-global-shortcuts.conf" id key
    [ -f "$conf" ] || return
    review_gate "users/ethan/kde-global-shortcuts.conf" || { say "   skipped kde-global-shortcuts"; return; }
    while read -r id key; do
        [ -n "$id" ] || continue
        case "$id" in \#*) continue ;; esac
        [ -n "$key" ] || continue
        if [ "$ME" = ethan ]; then
            kwriteconfig6 --file kglobalshortcutsrc --group services --group "$id" --key _launch "$key"
        else
            sudo -u ethan kwriteconfig6 --file kglobalshortcutsrc --group services --group "$id" --key _launch "$key"
        fi
        say "ethan-tier: shortcut $key -> $id"
    done < "$conf"
}

# --- ethan-tier: assert declared per-monitor taskbar launchers (privileged) ---
# Sets ONLY the `launchers` list of each panel's Icons-Only Task Manager; every
# other panel setting (height, position, tray, placement) is left untouched, and
# it is idempotent (a task manager already matching is skipped, with no restart).
#
# Each conf line names a monitor by CONNECTOR (kscreen-doctor output name). The
# config file only stores a screen *index* per panel (its `lastScreen`), so we
# bridge the two through kscreen's display `priority`: index = priority - 1
# (primary priority 1 -> index 0). Both sides are read live, so it stays correct
# across a monitor rearrange. Needs an active ethan Plasma session for the display
# query (skips with a warning otherwise, e.g. when run as the root operator).
#
# Detection is FULLY FILE-BASED — no plasmashell scripting API (evaluateScript
# returns nothing through qdbus, which silently masked every change before). A
# Python pass parses the live appletsrc directly (it runs AS ethan, the only user
# who can read it), matches each icontasks applet to its panel's screen index and
# hence to the conf, and emits a write line only where the launchers differ.
#
# Apply avoids a clobber race: writing launchers into a LIVE plasmashell only
# half-applies, and a later restart saves stale in-memory config over the edit. So
# when anything differs we STOP plasmashell, kwriteconfig6 the launchers straight
# into the file (nothing live to clobber it), then START it fresh so it reads the
# new file. Unchanged panels never stop plasmashell.
deploy_ethan_taskbar_launchers() {
    local conf="$REPO_ROOT/users/ethan/kde-taskbar-launchers.conf"
    [ -f "$conf" ] || return
    review_gate "users/ethan/kde-taskbar-launchers.conf" || { say "   skipped kde-taskbar-launchers"; return; }

    local uid; uid="$(id -u ethan)"
    # Helper commands that must reach the live session bus run AS ethan with it.
    local run=( )
    if [ "$ME" != ethan ]; then
        run=( sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" )
    fi

    local applet="$ETHAN_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    # Query the live display config once (tolerant: a hiccup must not abort the
    # whole deploy under `set -e`, so capture separately with `|| true`).
    local kj
    kj="$( "${run[@]}" kscreen-doctor -j 2>/dev/null || true )"

    # Compute the required writes from the files alone. Runs AS ethan (via `run`)
    # so it can read the appletsrc; kscreen JSON arrives in the KSCREEN_JSON env
    # var (stdin carries the Python program). Prints one tab-separated
    # "containment<TAB>applet<TAB>launchers" line per icontasks applet whose
    # launchers differ from the conf, nothing for those already correct. Exits 2
    # if it finds NO icontasks applet at all — a parse/layout failure we must not
    # mistake for "already up to date" (the bug that plagued the old version).
    local out rc
    out="$( "${run[@]}" env KSCREEN_JSON="$kj" python3 - "$conf" "$applet" <<'PY'
import json, os, sys

conf_path, applet_path = sys.argv[1], sys.argv[2]

# connector -> screen index (kscreen priority - 1; primary priority 1 -> index 0)
conn_index = {}
try:
    for o in json.loads(os.environ.get("KSCREEN_JSON", "")).get("outputs", []):
        if o.get("enabled") is False:
            continue
        pr = o.get("priority")
        if pr is None:
            continue
        conn_index[o.get("name")] = int(pr) - 1
except Exception as e:
    sys.stderr.write("taskbar: kscreen parse failed: %s\n" % e)

# screen index -> desired launchers (from the conf, keyed by connector)
index_want = {}
with open(conf_path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        conn, launchers = parts[0], parts[1].strip()
        idx = conn_index.get(conn)
        if idx is None:
            sys.stderr.write("taskbar: connector %s not among live outputs\n" % conn)
            continue
        index_want[idx] = launchers

# Parse the appletsrc into {group-path-tuple: {key: value}}. A header like
# [Containments][3][Applets][5][Configuration][General] becomes the tuple
# ("Containments","3","Applets","5","Configuration","General").
groups, cur = {}, None
with open(applet_path, encoding="utf-8") as f:
    for raw in f:
        s = raw.strip()
        if s.startswith("[") and s.endswith("]"):
            cur = tuple(s[1:-1].split("]["))
            groups.setdefault(cur, {})
        elif cur is not None and "=" in s and not s.startswith("#"):
            k, v = s.split("=", 1)
            groups[cur][k.strip()] = v

# Every containment's lastScreen (panels and desktops alike; only panels hold an
# icontasks applet, so recording all is harmless).
screen_of = {}
for path, kv in groups.items():
    if len(path) == 2 and path[0] == "Containments" and "lastScreen" in kv:
        try:
            screen_of[path[1]] = int(kv["lastScreen"])
        except ValueError:
            pass

def norm(s):
    return ",".join(t for t in s.split(",") if t)

writes, found = [], 0
for path, kv in groups.items():
    if len(path) == 4 and path[0] == "Containments" and path[2] == "Applets" \
            and kv.get("plugin") == "org.kde.plasma.icontasks":
        found += 1
        cid, aid = path[1], path[3]
        idx = screen_of.get(cid)
        if idx is None:
            sys.stderr.write("taskbar: icontasks in containment %s has no lastScreen\n" % cid)
            continue
        want = index_want.get(idx)
        if want is None:
            sys.stderr.write("taskbar: no conf entry for screen index %s (containment %s)\n" % (idx, cid))
            continue
        cfg = groups.get((path[0], cid, "Applets", aid, "Configuration", "General"), {})
        if norm(cfg.get("launchers", "")) == norm(want):
            continue
        writes.append((cid, aid, want))

if found == 0:
    sys.stderr.write("taskbar: no icontasks applets found in appletsrc — aborting\n")
    sys.exit(2)

for cid, aid, val in writes:
    sys.stdout.write("%s\t%s\t%s\n" % (cid, aid, val))
PY
)"
    rc=$?
    if [ "$rc" -eq 2 ]; then
        say "!! ethan-tier: taskbar — parser found no task manager applets (Plasma session up? layout unexpected); skipped"
        return
    fi
    if [ "$rc" -ne 0 ]; then
        say "!! ethan-tier: taskbar — parse failed (rc=$rc); skipped"
        return
    fi

    # Collect the writes (tab-separated: containment id, applet id, launchers).
    local -a writes=()
    local cid aid val
    while IFS=$'\t' read -r cid aid val; do
        [ -n "$cid" ] || continue
        writes+=("$cid"$'\t'"$aid"$'\t'"$val")
    done <<< "$out"

    if [ "${#writes[@]}" -eq 0 ]; then
        say "ethan-tier: taskbar launchers already up to date — nothing to do"
        return
    fi

    # STOP plasmashell so nothing overwrites our file edit, then write the
    # launchers straight into each applet's config group with kwriteconfig6.
    local kw=kwriteconfig6
    command -v kwriteconfig6 >/dev/null 2>&1 || kw=kwriteconfig5
    say "ethan-tier: taskbar — ${#writes[@]} panel(s) differ; stopping plasmashell to write"
    "${run[@]}" systemctl --user stop plasma-plasmashell.service 2>/dev/null \
        || "${run[@]}" kquitapp6 plasmashell 2>/dev/null || true

    local w
    for w in "${writes[@]}"; do
        IFS=$'\t' read -r cid aid val <<< "$w"
        "${run[@]}" "$kw" --file plasma-org.kde.plasma.desktop-appletsrc \
            --group Containments --group "$cid" --group Applets --group "$aid" \
            --group Configuration --group General --key launchers "$val"
        say "ethan-tier: taskbar wrote launchers -> containment $cid / applet $aid"
    done

    # START plasmashell fresh; it reads the freshly-written file and renders.
    "${run[@]}" systemctl --user start plasma-plasmashell.service 2>/dev/null \
        || "${run[@]}" kstart plasmashell >/dev/null 2>&1 || true
    say "ethan-tier: taskbar launchers applied; plasmashell restarted"
}

# --- root-tier: host scripts + sudoers drop-ins (need root) ---
deploy_root_tier() {
    local f base rel tmp
    for f in "$REPO_ROOT"/system/usr-local-sbin/*; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="system/usr-local-sbin/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        sudo install -o root -g root -m 0755 "$f" "/usr/local/sbin/$base"
        say "root-tier: installed /usr/local/sbin/$base"
    done
    for f in "$REPO_ROOT"/system/etc-sudoers.d/*; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="system/etc-sudoers.d/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        tmp="$(mktemp)"; install -m 0440 "$f" "$tmp"
        if sudo visudo -cf "$tmp" >/dev/null; then
            sudo install -o root -g root -m 0440 "$f" "/etc/sudoers.d/$base"
            say "root-tier: installed /etc/sudoers.d/$base (validated)"
        else
            say "!! REFUSED /etc/sudoers.d/$base — visudo -c failed; left unchanged"
        fi
        rm -f "$tmp"
    done
    # world-readable host data (the shared protect-core ruleset consumed by
    # devscaffold + protect-repo.sh, and the merge-policy definition consumed by
    # devscaffold + set-merge-policy.sh); mirrors the repo path under
    # system/usr-local-share/ into /usr/local/share/ preserving subdirs.
    if [ -d "$REPO_ROOT"/system/usr-local-share ]; then
        while IFS= read -r -d '' f; do
            rel="${f#"$REPO_ROOT"/}"                       # e.g. system/usr-local-share/devscaffold/x.json
            dest="/usr/local/share/${rel#system/usr-local-share/}"
            review_gate "$rel" || { say "   skipped $rel"; continue; }
            sudo install -o root -g root -m 0644 -D "$f" "$dest"
            say "root-tier: installed $dest"
        done < <(find "$REPO_ROOT"/system/usr-local-share -type f -print0)
    fi
}

case "$ME" in
    ethan|root)
        say "== deploy (operator: $ME) =="
        run_builders             # regenerate artifacts before shipping them
        deploy_root_tier
        deploy_ethan_tier
        deploy_todo_ethan        # reviewed copy of todo/bin/todo -> ethan's ~/.local/bin (before todo-capture)
        deploy_ethan_bin         # PATH executables (todo-capture) -> ethan's ~/.local/bin
        deploy_ethan_config      # ~/.config trees (fastfetch, systemd units, ...) -> ethan's ~/.config
        deploy_steam_tracker     # steam-price-tracker: ensure SMTP secret + enable resume watcher
        deploy_desktop_entries   # .desktop launchers -> ethan's menu + desktop
        deploy_ethan_shortcuts   # global hotkeys -> ~ethan/.config/kglobalshortcutsrc
        deploy_ethan_taskbar_launchers  # per-monitor taskbar pins -> live plasmashell
        deploy_dev_tier          # deploys dev's CLAUDE.md via sudo -u dev
        deploy_dev_skills        # deploys dev's ~/.claude/skills via sudo -u dev
        deploy_dev_memory        # deploys dev's ~/.claude Claude memory via sudo -u dev
        deploy_dev_bashrc        # deploys dev's ~/.bashrc.d fragments (cc alias) via sudo -u dev
        deploy_dev_statusline    # deploys dev's ~/.claude status line + wires settings.json
        deploy_todo_dev          # copies todo/bin/todo -> dev's ~/.local/bin via sudo -u dev
        ;;
    *)
        say "install.sh must be run as ethan (it deploys privileged files)." >&2
        say "current user: '$ME' — refusing." >&2
        exit 1 ;;
esac
say "== done =="
