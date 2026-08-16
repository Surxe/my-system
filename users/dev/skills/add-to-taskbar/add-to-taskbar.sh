#!/usr/bin/env bash
# add-to-taskbar.sh — add one app launcher to a taskbar group in
# users/ethan/kde-taskbar-groups.conf (the declared config install.sh asserts).
#
# This ONLY edits the conf (launcher URLs are DATA, not code run as ethan), so
# there is no localbin/security dance here. Deployment is still ethan's job:
# after this edits the conf, ethan runs users/install.sh to assert it onto the
# live Launcher Group widgets.
#
# Friendly taskbar names -> conf [connector] / group <Name>:
#   hdmi1 -> [HDMI-A-1] group coding   (left monitor)
#   hdmi2 -> [HDMI-A-1] group media    (left monitor)
#   dp2   -> [DP-2]     group firefox  (right monitor)
#   dp1   -> stock Icons-Only Task Manager (default) — NOT a Launcher Group;
#            it has no launcher list this flow manages (only show-minimized-tasks).
#
# Usage:
#   add-to-taskbar.sh --taskbar <hdmi1|hdmi2|dp2> --launcher <url> [--conf <path>]
#
#   <url> is a launcher URL: applications:<id>.desktop (menu app),
#         file:///…​.desktop (flatpak export), or preferred://<service> (warned).
#
# Idempotent: if the launcher is already in the group, it changes nothing and
# exits 0. Errors (unknown taskbar, dp1, missing group) exit non-zero.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../../.." && pwd)"
CONF_DEFAULT="$REPO_ROOT/users/ethan/kde-taskbar-groups.conf"

taskbar=""; launcher=""; conf="$CONF_DEFAULT"

die() { echo "add-to-taskbar: $*" >&2; exit 1; }

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --taskbar)  taskbar="${2:-}"; shift 2 ;;
        --launcher) launcher="${2:-}"; shift 2 ;;
        --conf)     conf="${2:-}"; shift 2 ;;
        -h|--help)  usage 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done

[ -n "$taskbar" ]  || die "missing --taskbar (hdmi1|hdmi2|dp2)"
[ -n "$launcher" ] || die "missing --launcher <url>"
[ -f "$conf" ]     || die "conf not found: $conf"

# Map the friendly name to a connector section + group name.
case "$taskbar" in
    hdmi1) connector="HDMI-A-1"; group="coding" ;;
    hdmi2) connector="HDMI-A-1"; group="media" ;;
    dp2)   connector="DP-2";     group="firefox" ;;
    dp1)
        die "dp1 is the stock Icons-Only Task Manager (the default taskbar), not a
   Launcher Group — this flow manages Launcher Group widgets only, and dp1's
   only install.sh-managed setting is the 'show-minimized-tasks' directive.
   To pin an app there, use the KDE panel GUI (right-click the app -> Pin)."
        ;;
    *) die "unknown taskbar '$taskbar' (expected hdmi1, hdmi2, or dp2; dp1 is unmanaged)" ;;
esac

# Validate the launcher URL vocabulary.
case "$launcher" in
    applications:*.desktop|file://*.desktop) ;;
    preferred://*)
        echo "add-to-taskbar: WARNING — preferred:// aliases break the widget's" >&2
        echo "   hide-when-visible logic (its app-key won't match the app's windows)." >&2
        echo "   Prefer an explicit applications:<id>.desktop. Continuing anyway." >&2
        ;;
    *) die "launcher '$launcher' is not a launcher URL
   (expected applications:<id>.desktop, file:///…​.desktop, or preferred://<service>)" ;;
esac

# Best-effort existence check for applications:<id>.desktop (dev often cannot read
# ~ethan/.local, so a miss is only a warning, never a failure).
case "$launcher" in
    applications:*.desktop)
        base="${launcher#applications:}"
        found=""
        for d in /usr/share/applications \
                 /var/lib/flatpak/exports/share/applications \
                 "$HOME/.local/share/flatpak/exports/share/applications" \
                 "$REPO_ROOT/users/ethan/desktop-entries"; do
            [ -e "$d/$base" ] && { found="$d/$base"; break; }
        done
        [ -n "$found" ] || echo "add-to-taskbar: note — $base not found in dev-readable app dirs;" \
                                "assuming it exists in ethan's menu." >&2
        ;;
esac

# Mutate the conf (idempotent insert under [connector] -> group <group>).
CONF="$conf" CONNECTOR="$connector" GROUP="$group" LAUNCHER="$launcher" \
python3 - <<'PY'
import os, sys

conf = os.environ["CONF"]
connector = os.environ["CONNECTOR"]
group = os.environ["GROUP"]
url = os.environ["LAUNCHER"].strip()

with open(conf, encoding="utf-8") as f:
    lines = f.read().splitlines(keepends=True)

def is_section(s):   return s.lstrip().startswith("[") and "]" in s
def section_name(s): x = s.strip(); return x[1:x.index("]")].strip()
def indented(s):     return s[:1] in (" ", "\t")

# Locate the target [connector] section.
sec_start = None
for i, ln in enumerate(lines):
    if is_section(ln) and section_name(ln) == connector:
        sec_start = i
        break
if sec_start is None:
    sys.stderr.write("add-to-taskbar: section [%s] not found in conf — add the "
                     "monitor section first.\n" % connector)
    sys.exit(3)

sec_end = len(lines)
for i in range(sec_start + 1, len(lines)):
    if is_section(lines[i]):
        sec_end = i
        break

# Locate `group <group>` within the section.
grp_line = None
for i in range(sec_start + 1, sec_end):
    s = lines[i].strip()
    if s.lower().startswith("group ") and s[6:].strip().lower() == group.lower():
        grp_line = i
        break
if grp_line is None:
    sys.stderr.write("add-to-taskbar: no `group %s` under [%s] — create the Launcher "
                     "Group widget in the GUI and set its Group name, then add the "
                     "group line to the conf.\n" % (group, connector))
    sys.exit(4)

# The group's launcher lines are the indented lines following it.
blk_end = grp_line + 1
while blk_end < sec_end and (indented(lines[blk_end]) or not lines[blk_end].strip()):
    # stop at a blank line that precedes a non-indented line (end of block)
    if not lines[blk_end].strip():
        break
    blk_end += 1

existing = [lines[i].strip() for i in range(grp_line + 1, blk_end) if lines[i].strip()]
if url in existing:
    print("already present: %s is in [%s] group %s — no change." % (url, connector, group))
    sys.exit(0)

# Match the indentation of the first existing launcher, else default to 2 spaces.
indent = "  "
for i in range(grp_line + 1, blk_end):
    if lines[i].strip():
        indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
        break

new_line = "%s%s\n" % (indent, url)
# Insert after the last non-blank launcher line (or right after the group line).
insert_at = grp_line + 1
for i in range(grp_line + 1, blk_end):
    if lines[i].strip():
        insert_at = i + 1
lines.insert(insert_at, new_line)

with open(conf, "w", encoding="utf-8") as f:
    f.writelines(lines)

print("added %s to [%s] group %s." % (url, connector, group))
PY

echo
echo "Updated group block:"
awk -v conn="$connector" -v grp="$group" '
  /^\[/ { insec = ($0 ~ ("^\\[" conn "\\]")); ingrp = 0 }
  insec && $0 ~ ("^[[:space:]]*group[[:space:]]+" grp "[[:space:]]*$") { ingrp = 1; print; next }
  ingrp && /^[[:space:]]/ { print; next }
  ingrp && /^[^[:space:]]/ { ingrp = 0 }
' "$conf" | sed 's/^/   /'
