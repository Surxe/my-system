#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

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
deploy_dev_statusline
