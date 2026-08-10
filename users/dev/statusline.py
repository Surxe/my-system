#!/usr/bin/env python3
"""Single-line Claude Code status bar.

Reads the status-line JSON payload on stdin and prints ONE line (no trailing
newline segments, no vertical growth). Layout:

    <session>  ·  <model>  ·  ctx N%  ·  5h N%  ·  wk N%  ·  <folder>

Percentages are color-coded green/yellow/red by fullness. The 5h/wk rate-limit
segments are account-wide (across all sessions) and are simply omitted when the
payload doesn't carry them (early in a session, or non Pro/Max).

Deployed to ~/.claude/statusline.py by my-system's users/install.sh and wired in
as settings.json -> statusLine. Stdlib only; must never crash the bar.
"""

import io
import json
import os
import sys

# Force UTF-8 stdout so the middot separator never trips a narrow locale.
if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SEP = "  \x1b[2m·\x1b[0m  "  # dim middle dot between segments

_ANSI = {
    "reset": "\x1b[0m",
    "bold": "\x1b[1m",
    "dim": "\x1b[2m",
    "green": "\x1b[32m",
    "yellow": "\x1b[33m",
    "red": "\x1b[31m",
    "cyan": "\x1b[36m",
}

# Percentage color thresholds (<=green stays green, <=yellow is yellow, else red).
T_GREEN = 60
T_YELLOW = 80


def _c(text, *codes):
    return "".join(_ANSI[c] for c in codes if c in _ANSI) + text + _ANSI["reset"]


def _pct_color(pct):
    if pct <= T_GREEN:
        return "green"
    if pct <= T_YELLOW:
        return "yellow"
    return "red"


def _num(v):
    """Coerce a possibly-null/str numeric to float, or None."""
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _session_name(data):
    """Prefer the payload's session_name (custom /rename or AI title); else the
    latest ai-title from the transcript; else 'untitled'."""
    name = data.get("session_name")
    if isinstance(name, str) and name.strip():
        return name.strip()

    path = data.get("transcript_path")
    if path and os.path.isfile(path):
        title = None
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    if '"ai-title"' not in line:
                        continue
                    try:
                        obj = json.loads(line)
                    except ValueError:
                        continue
                    if obj.get("type") == "ai-title" and obj.get("aiTitle"):
                        title = obj["aiTitle"]  # keep the last one
        except OSError:
            title = None
        if title:
            return title
    return "untitled"


def _model(data):
    name = (data.get("model") or {}).get("display_name") or ""
    # Strip a trailing "(… context)" suffix, e.g. "Opus (1M context)".
    if "(" in name:
        name = name[: name.rfind("(")].strip()
    return name


def render(data):
    parts = []

    parts.append(_c(_session_name(data), "bold"))

    model = _model(data)
    if model:
        parts.append(model)

    # Context %
    cw = data.get("context_window") or {}
    ctx = _num(cw.get("used_percentage")) or 0.0
    parts.append("ctx " + _c(f"{ctx:.0f}%", _pct_color(ctx)))

    # Rate-limit windows (account-wide). Each may be absent.
    rl = data.get("rate_limits") or {}
    for key, label in (("five_hour", "5h"), ("seven_day", "wk")):
        window = rl.get(key) or {}
        val = _num(window.get("used_percentage"))
        if val is not None:
            parts.append(f"{label} " + _c(f"{val:.0f}%", _pct_color(val)))

    # Folder
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or ""
    folder = os.path.basename(cwd.rstrip("/")) if cwd else ""
    if folder:
        parts.append(_c(folder, "cyan"))

    return SEP.join(parts)


# --- self-test -------------------------------------------------------------

MOCK_FULL = {
    "session_name": "Fix lost todo items",
    "model": {"display_name": "Opus (1M context)"},
    "context_window": {"used_percentage": 8},
    "rate_limits": {
        "five_hour": {"used_percentage": 23.5},
        "seven_day": {"used_percentage": 41.2},
    },
    "workspace": {"current_dir": "/srv/dev/repos/my-system"},
}

MOCK_BARE = {
    # no session_name, no rate_limits, null context -> untitled + no 5h/wk
    "model": {"display_name": "Opus"},
    "context_window": {"used_percentage": None},
    "workspace": {"current_dir": "/srv/dev/repos/todo"},
}


def selftest():
    ok = True
    for label, mock in [("full payload", MOCK_FULL), ("bare payload", MOCK_BARE)]:
        out = render(mock)
        if not out.strip() or "\n" in out:
            print(f"FAIL: {label}: empty or multi-line output", file=sys.stderr)
            ok = False
        else:
            print(f"--- {label} ---")
            print(out)
    return ok


def main():
    if "--selftest" in sys.argv:
        sys.exit(0 if selftest() else 1)
    try:
        data = json.loads(sys.stdin.read())
        print(render(data))
    except Exception:
        # Never crash the status bar; emit an empty line.
        print("")
        sys.exit(0)


if __name__ == "__main__":
    main()
