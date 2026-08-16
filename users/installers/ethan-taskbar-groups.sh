#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: assert declared taskbar group config onto EXISTING widgets (privileged) ---
# Reads users/ethan/kde-taskbar-groups.conf and, per monitor:
#   - sets each "Launcher Group" widget's launchers= (matched by its groupName),
#   - flips showOnlyMinimized=true on the panel's one empty Icons-Only Task Manager
#     when the conf has `show-minimized-tasks`,
#   - strips stray MySystemGroup/MySystemSep marker keys off any NON-Launcher-Group
#     widget (leftovers from earlier attempts that plasmashell's id-reuse glued on).
#
# EDIT-EXISTING ONLY: it never creates or deletes widgets (creating panel widgets
# from a config file is unreliable in Plasma). If a conf group names a widget that
# isn't present, it WARNS (add it via the GUI and set its Group name). Ownership is
# gated on plugin id `org.surxe.launchergroup` — a stray marker on a real widget
# (task manager, now-playing, …) can never make this touch it.
#
# Monitor<->panel mapping: conf sections are keyed by CONNECTOR (kscreen output
# name); the appletsrc stores a screen index per panel (lastScreen), bridged via
# kscreen display priority (index = priority - 1), read live. Needs an active ethan
# Plasma session for the display query.
#
# A Python pass (run AS ethan, the only user who can read the appletsrc) parses the
# live file and emits the exact per-applet key writes needed — nothing if already in
# sync. Apply mirrors the original launchers installer: STOP plasmashell (so a live
# save can't clobber the edit and the widgets re-read config fresh), kwriteconfig6
# each key straight into the file, then START plasmashell. No changes -> no restart.
deploy_ethan_taskbar_groups() {
    local conf="$REPO_ROOT/users/ethan/kde-taskbar-groups.conf"
    [ -f "$conf" ] || return
    review_gate "users/ethan/kde-taskbar-groups.conf" || { say "   skipped kde-taskbar-groups"; return; }

    local uid; uid="$(id -u ethan)"
    local run=( )
    if [ "$ME" != ethan ]; then
        run=( sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" )
    fi

    local applet="$ETHAN_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    local kj; kj="$( "${run[@]}" kscreen-doctor -j 2>/dev/null || true )"

    # Compute the key writes. Emits tab-separated "cid<TAB>aid<TAB>key<TAB>value"
    # per change (value == the delete sentinel to remove a key). Warnings go to
    # stderr (shown to the user). Exit 2 = no panels found (parse/session failure).
    local out rc
    out="$( "${run[@]}" env KSCREEN_JSON="$kj" python3 - "$conf" "$applet" <<'PY'
import json, os, sys

conf_path, applet_path = sys.argv[1], sys.argv[2]
LG = "org.surxe.launchergroup"
IT = "org.kde.plasma.icontasks"
STRAY = ("MySystemGroup", "MySystemSep")
DEL = "__MYSYS_DELETE__"

conn_index = {}
try:
    for o in json.loads(os.environ.get("KSCREEN_JSON", "") or "{}").get("outputs", []):
        if o.get("enabled") is False:
            continue
        pr = o.get("priority")
        if pr is not None:
            conn_index[o.get("name")] = int(pr) - 1
except Exception as e:
    sys.stderr.write("taskbar-groups: kscreen parse failed: %s\n" % e)
index_conn = {v: k for k, v in conn_index.items()}

def norm(s):
    return ",".join(t.strip() for t in (s or "").split(",") if t.strip())

# conf: connector -> {"groups": {name: csv}, "showmin": bool}
conf, cur, grp = {}, None, None
with open(conf_path, encoding="utf-8") as f:
    for raw in f:
        line = raw.rstrip("\n"); s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("[") and "]" in s:
            cur = s[1:s.index("]")].strip()
            conf.setdefault(cur, {"groups": {}, "showmin": False}); grp = None; continue
        if cur is None:
            continue
        low = s.lower()
        if low == "show-minimized-tasks":
            conf[cur]["showmin"] = True; grp = None; continue
        if low.startswith("group "):
            grp = s[5:].strip(); conf[cur]["groups"].setdefault(grp, []); continue
        if line[:1] in (" ", "\t") and grp is not None:
            conf[cur]["groups"][grp].append(s)
        else:
            grp = None
for c in conf.values():
    c["groups"] = {k: ",".join(v) for k, v in c["groups"].items()}

# appletsrc -> {header_tuple: {k: v}}
G, curh = {}, None
with open(applet_path, encoding="utf-8") as f:
    for raw in f:
        t = raw.rstrip("\n")
        if t.startswith("[") and t.endswith("]"):
            curh = tuple(t[1:-1].split("]["))
            G.setdefault(curh, {})
        elif curh is not None and "=" in t and not t.startswith("#"):
            k, v = t.split("=", 1); G[curh][k.strip()] = v

def plugin(cid, aid): return G.get(("Containments", cid, "Applets", aid), {}).get("plugin")
def gen(cid, aid):    return G.get(("Containments", cid, "Applets", aid, "Configuration", "General"), {})

actions = []
panels = [h[1] for h, kv in G.items()
          if len(h) == 2 and h[0] == "Containments" and kv.get("plugin") == "org.kde.panel"]
if not panels:
    sys.stderr.write("taskbar-groups: no panels found — aborting\n"); sys.exit(2)

for P in panels:
    ls = G.get(("Containments", P), {}).get("lastScreen")
    if ls is None:
        continue
    try:
        conn = index_conn.get(int(ls))
    except ValueError:
        conn = None
    if conn is None or conn not in conf:
        continue
    c = conf[conn]
    applets = [h[3] for h in G if len(h) == 4 and h[0] == "Containments"
               and h[1] == P and h[2] == "Applets"]

    lg = {}
    for aid in applets:
        if plugin(P, aid) == LG:
            gn = (gen(P, aid).get("groupName", "") or "").strip()
            if gn:
                lg[gn] = aid
    for name, csv in c["groups"].items():
        aid = lg.get(name)
        if aid is None:
            sys.stderr.write("taskbar-groups: %s — no Launcher Group widget named '%s' "
                             "(add it in the GUI and set its Group name)\n" % (conn, name))
            continue
        if norm(gen(P, aid).get("launchers")) != norm(csv):
            actions.append((P, aid, "launchers", csv))

    if c["showmin"]:
        empties = [aid for aid in applets
                   if plugin(P, aid) == IT and not norm(gen(P, aid).get("launchers"))]
        if len(empties) == 1:
            aid = empties[0]
            if (gen(P, aid).get("showOnlyMinimized", "") or "").lower() != "true":
                actions.append((P, aid, "showOnlyMinimized", "true"))
        elif not empties:
            sys.stderr.write("taskbar-groups: %s — show-minimized-tasks: no empty task manager\n" % conn)
        else:
            sys.stderr.write("taskbar-groups: %s — show-minimized-tasks: multiple empty task managers, skipping\n" % conn)

# strip stray markers off any NON-Launcher-Group applet, anywhere
for h in G:
    if len(h) == 4 and h[0] == "Containments" and h[2] == "Applets":
        cid, aid = h[1], h[3]
        if plugin(cid, aid) != LG:
            g = gen(cid, aid)
            for k in STRAY:
                if k in g:
                    actions.append((cid, aid, k, DEL))

for cid, aid, key, val in actions:
    sys.stdout.write("%s\t%s\t%s\t%s\n" % (cid, aid, key, val))
PY
)" && rc=0 || rc=$?

    if [ "${rc:-0}" -eq 2 ]; then
        say "!! ethan-tier: taskbar-groups — no panels found (Plasma session up?); skipped"
        return
    fi
    if [ "${rc:-0}" -ne 0 ]; then
        say "!! ethan-tier: taskbar-groups — parse failed (rc=${rc}); skipped"
        return
    fi
    if [ -z "$out" ]; then
        say "ethan-tier: taskbar groups already in sync — nothing to do"
        return
    fi

    say "ethan-tier: taskbar-groups — applying $(printf '%s\n' "$out" | grep -c .) config change(s)"

    local kw=kwriteconfig6
    "${run[@]}" bash -c 'command -v kwriteconfig6 >/dev/null 2>&1' || kw=kwriteconfig5

    "${run[@]}" systemctl --user stop plasma-plasmashell.service 2>/dev/null \
        || "${run[@]}" kquitapp6 plasmashell 2>/dev/null || true

    local cid aid key val
    while IFS=$'\t' read -r cid aid key val; do
        [ -n "$cid" ] || continue
        if [ "$val" = "__MYSYS_DELETE__" ]; then
            "${run[@]}" "$kw" --file plasma-org.kde.plasma.desktop-appletsrc \
                --group Containments --group "$cid" --group Applets --group "$aid" \
                --group Configuration --group General --key "$key" --delete
            say "ethan-tier: taskbar-groups cleared $key on containment $cid / applet $aid"
        else
            "${run[@]}" "$kw" --file plasma-org.kde.plasma.desktop-appletsrc \
                --group Containments --group "$cid" --group Applets --group "$aid" \
                --group Configuration --group General --key "$key" "$val"
            say "ethan-tier: taskbar-groups set $key on containment $cid / applet $aid"
        fi
    done <<< "$out"

    "${run[@]}" systemctl --user start plasma-plasmashell.service 2>/dev/null \
        || "${run[@]}" kstart plasmashell >/dev/null 2>&1 || true
    say "ethan-tier: taskbar-groups applied; plasmashell restarted"
}
deploy_ethan_taskbar_groups
