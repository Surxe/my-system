#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

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
deploy_ethan_taskbar_launchers
