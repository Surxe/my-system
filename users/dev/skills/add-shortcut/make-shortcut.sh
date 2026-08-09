#!/usr/bin/env bash
#
# make-shortcut.sh — generate a KDE `.desktop` launcher (the /add-shortcut skill's
# worker). Runs as `dev`; writes the launcher into this repo's canonical source
# dir. It NEVER touches ethan's home — deployment to the menu + desktop is done
# later by `users/install.sh` (run as ethan). See SKILL.md for the full flow.
#
# Model (why this is safe from an unprivileged dev):
#   - Only the `.desktop` file is copied into ethan's home by install.sh.
#   - Exec/Icon and any generated runner stay in-repo and are referenced by
#     absolute path; ethan reads/execs them via the shared `developers` group.
#
# Output (default --outdir): users/ethan/desktop-entries/
#   <slug>.desktop           the launcher
#   <slug>.run.sh            a pausing terminal runner (only for wrapped terminal
#                            commands; keeps the window open to read output/errors)
#
# Usage:
#   make-shortcut.sh --command <cmd> [options]
#
# Options:
#   --command <cmd>     REQUIRED. Command to launch (may include args).
#   --name <name>       Display name. Default: derived from the command.
#   --comment <text>    Tooltip/Comment. Default: "Launch <name>".
#   --icon <name|path>  Themed icon name or absolute icon path. Default depends
#                       on --terminal/--gui.
#   --terminal          Run in a terminal (DEFAULT).
#   --gui               Windowed app; no terminal, no runner wrapper.
#   --no-wrap           Terminal mode, but point Exec straight at --command
#                       (use when the command already keeps its own window open).
#   --workdir <dir>     Working directory (Path=). Default: inferred from the
#                       command's path if it's absolute, else omitted.
#   --categories <c>    Freedesktop categories, ';'-separated. Default: Utility.
#   --source <text>     Provenance note for the header. Default: inferred repo
#                       name from the command/workdir path, else "manual".
#   --filename <slug>   Override the output basename (without extension).
#   --outdir <dir>      Output directory. Default: the canonical desktop-entries/.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # …/users/dev/skills/add-shortcut
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"             # …/my-system
DEFAULT_OUTDIR="$REPO_ROOT/users/ethan/desktop-entries"

die(){ printf 'make-shortcut: %s\n' "$*" >&2; exit 1; }

# --- defaults ---
command_str=""
name=""
comment=""
icon=""
terminal=true
wrap=true
workdir=""
categories="Utility"
source_note=""
filename=""
outdir="$DEFAULT_OUTDIR"

# --- parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --command)    command_str="${2:-}"; shift 2 ;;
    --name)       name="${2:-}"; shift 2 ;;
    --comment)    comment="${2:-}"; shift 2 ;;
    --icon)       icon="${2:-}"; shift 2 ;;
    --terminal)   terminal=true; shift ;;
    --gui)        terminal=false; shift ;;
    --no-wrap)    wrap=false; shift ;;
    --workdir)    workdir="${2:-}"; shift 2 ;;
    --categories) categories="${2:-}"; shift 2 ;;
    --source)     source_note="${2:-}"; shift 2 ;;
    --filename)   filename="${2:-}"; shift 2 ;;
    --outdir)     outdir="${2:-}"; shift 2 ;;
    -h|--help)    sed -n '2,45p' "$0"; exit 0 ;;
    *)            die "unknown argument: $1" ;;
  esac
done

[ -n "$command_str" ] || die "--command is required"

# First whitespace-separated token of the command (used for name/workdir/source).
first_token="${command_str%%[[:space:]]*}"

# --- derive name ---
if [ -z "$name" ]; then
  base="$(basename "$first_token")"
  base="${base%.*}"                              # strip extension
  # Title-case words split on - and _ :
  name="$(printf '%s' "$base" | tr '_-' '  ' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) substr($i,2)}1')"
  [ -n "$name" ] || name="$base"
fi
[ -n "$comment" ] || comment="Launch $name"

# --- slug / filename ---
if [ -z "$filename" ]; then
  filename="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-|-$//g')"
fi
[ -n "$filename" ] || die "could not derive a filename (pass --filename)"

# --- infer workdir + source from a repo command path ---
# Only for /srv/dev/repos paths — a repo script usually wants to run from its
# dir; system binaries (e.g. /usr/bin/foo) get no Path.
if [ -z "$workdir" ]; then
  case "$first_token" in
    /srv/dev/repos/*) [ -e "$first_token" ] && workdir="$(dirname "$first_token")" ;;
  esac
fi
if [ -z "$source_note" ]; then
  probe="${workdir:-$first_token}"
  case "$probe" in
    /srv/dev/repos/*) source_note="$(printf '%s' "${probe#/srv/dev/repos/}" | cut -d/ -f1)" ;;
    *)                source_note="manual" ;;
  esac
fi

# --- default icon ---
if [ -z "$icon" ]; then
  if [ "$terminal" = true ]; then icon="utilities-terminal"; else icon="application-x-executable"; fi
fi

mkdir -p "$outdir"
desktop_path="$outdir/$filename.desktop"

# --- Exec + optional runner ------------------------------------------------
exec_line="$command_str"
runner_path=""
if [ "$terminal" = true ] && [ "$wrap" = true ]; then
  runner_path="$outdir/$filename.run.sh"
  cat > "$runner_path" <<RUNNER
#!/usr/bin/env bash
# GENERATED by /add-shortcut (make-shortcut.sh) — regenerate, don't hand-edit.
# Runner for "$name": run the command, then pause so a terminal launch stays
# readable (KDE closes the window on exit otherwise).
set -uo pipefail
$command_str
status=\$?
if [ -t 0 ]; then
  echo
  read -n1 -rp "Done (exit \$status). Press any key to close…"
  echo
fi
exit "\$status"
RUNNER
  chmod 0775 "$runner_path"
  exec_line="$runner_path"
fi

# --- write the .desktop ----------------------------------------------------
{
  echo "[Desktop Entry]"
  echo "# source: $source_note  # via /add-shortcut (do not hand-edit; regenerate)"
  echo "Type=Application"
  echo "Name=$name"
  echo "Comment=$comment"
  echo "Exec=$exec_line"
  [ -n "$workdir" ] && echo "Path=$workdir"
  echo "Icon=$icon"
  echo "Terminal=$([ "$terminal" = true ] && echo true || echo false)"
  # Categories must end with a trailing ';' per the spec.
  echo "Categories=${categories%;};"
} > "$desktop_path"
chmod 0664 "$desktop_path"

# --- validate (best effort) ------------------------------------------------
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop_path" || echo "make-shortcut: desktop-file-validate reported warnings (above)" >&2
fi

# --- report ----------------------------------------------------------------
echo "Wrote $desktop_path"
[ -n "$runner_path" ] && echo "Wrote $runner_path"
echo
echo "Next, to deploy to ethan's menu + desktop (run as ethan):"
echo "  /srv/dev/repos/my-system/users/install.sh"
echo "Then click 'Trust'/'Allow' once on the new desktop icon (KDE prompts on first launch)."
