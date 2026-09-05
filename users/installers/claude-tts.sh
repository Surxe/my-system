#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- claude-tts: spoken Claude output over the dev->ethan audio bridge ---
# Claude runs as dev, which is walled off from Ethan's audio server, so this mirrors
# the clip-discord bridge: dev synthesizes a WAV and drops it in a developers-group
# spool; an ethan-side systemd USER path unit plays it. This step does what the
# generic copies can't -- it spans both users and enables the units:
#   dev side  (dev's OWN home, no review gate): tts CLI, narrate.py, kokoro_synth.py,
#             the kokoro synth bootstrap, and the Stop hook wired into
#             dev's settings.json (merge-only).
#   spool     (shared): /srv/dev/tts/queue, owned by dev, group-writable + setgid.
#   ethan side(review-gated vs claude-tts's approved upstream): tts-speak + 4 units,
#             then enable the two path watchers in Ethan's user systemd.
# The bin/units live in the claude-tts repo (cross-repo, like `todo`); see common.sh
# for CLAUDE_TTS_REPO / CLAUDE_TTS_BASE_REF.
SPOOL_ROOT="/srv/dev/tts"          # ethan-owned parent (dev can't write /srv/dev itself)
SPOOL="$SPOOL_ROOT/queue"          # dev-populated queue subtree, via the developers group

deploy_claude_tts() {
    local repo="$CLAUDE_TTS_REPO" uid
    uid="$(id -u ethan)"
    [ -d "$repo" ] || { say "claude-tts: no $repo — skipping"; return; }

    # ---- dev side: dev's own files, so no review gate (same trust as dev-bin) ----
    local devrun=( ); [ "$ME" = dev ] || devrun=( sudo -u dev )

    "${devrun[@]}" install -D -m 0755 "$repo/bin/tts" "$DEV_HOME/.local/bin/tts"
    say "dev-tier: installed $DEV_HOME/.local/bin/tts"
    "${devrun[@]}" install -D -m 0644 "$repo/lib/narrate.py" \
        "$DEV_HOME/.local/share/claude-tts/narrate.py"
    say "dev-tier: installed $DEV_HOME/.local/share/claude-tts/narrate.py"
    "${devrun[@]}" install -D -m 0644 "$repo/lib/kokoro_synth.py" \
        "$DEV_HOME/.local/share/claude-tts/kokoro_synth.py"
    say "dev-tier: installed $DEV_HOME/.local/share/claude-tts/kokoro_synth.py"

    # dev-side synth watcher: text dropped in the spool (e.g. by the clipboard
    # hotkey) is synthesized HERE, because the kokoro engine lives in ~dev (0700)
    # and ethan cannot run it. dev's OWN units in dev's user systemd -> no review gate (dev
    # running dev's code). dev has lingering, so the .path stays armed at rest.
    local du duid
    for du in claude-tts-synth.path claude-tts-synth.service; do
        "${devrun[@]}" install -D -m 0644 "$repo/systemd/$du" \
            "$DEV_HOME/.config/systemd/user/$du"
        say "dev-tier: installed $DEV_HOME/.config/systemd/user/$du"
    done
    duid="$(id -u dev)"
    if [ "$ME" = dev ]; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now claude-tts-synth.path \
            || say "!! could not enable claude-tts-synth.path"
    else
        sudo -u dev XDG_RUNTIME_DIR="/run/user/$duid" systemctl --user daemon-reload || true
        sudo -u dev XDG_RUNTIME_DIR="/run/user/$duid" systemctl --user \
            enable --now claude-tts-synth.path \
            || say "!! could not enable claude-tts-synth.path as dev (dev lingering must be on)"
    fi
    say "dev-tier: claude-tts synth watcher wired"

    # Kokoro synth engine into dev's home (idempotent; big download on first run
    # only). Self-contained venv + ONNX model (~340MB), no sudo -- espeak-ng is
    # bundled in a wheel.
    "${devrun[@]}" bash "$repo/setup/install-kokoro.sh" \
        || say "!! claude-tts: kokoro bootstrap failed (check network / disk)"

    # Wire the Stop hook into dev's settings.json (merge-only, idempotent). Harmless
    # when off: `tts hook` no-ops unless a session ran `tts on`.
    "${devrun[@]}" python3 - "$DEV_HOME/.claude/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except (OSError, ValueError):
    data = {}
cmd = "$HOME/.local/bin/tts hook"
stop = data.setdefault("hooks", {}).setdefault("Stop", [])
present = any(
    isinstance(g, dict) and any(
        isinstance(h, dict) and h.get("command") == cmd for h in g.get("hooks", [])
    )
    for g in stop
)
if not present:
    stop.append({"hooks": [{"type": "command", "command": cmd}]})
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    f.write(json.dumps(data, indent=2) + "\n")
PY
    say "dev-tier: wired Stop hook (tts hook) -> $DEV_HOME/.claude/settings.json"

    # ---- shared spool ----
    # /srv/dev is ethan-owned and NOT dev-writable, so the OPERATOR (ethan/root)
    # provisions the spool root the way /srv/dev/clips exists: an ethan-owned, setgid,
    # group-writable dir dev can then populate via the `developers` group. (Running
    # this step standalone as dev can't create it -- deploy via install.sh as ethan.)
    if install -d -m 2775 "$SPOOL_ROOT" 2>/dev/null; then
        chgrp developers "$SPOOL_ROOT" 2>/dev/null || true
        chmod 2775 "$SPOOL_ROOT"
        say "ethan-tier: claude-tts spool root ready at $SPOOL_ROOT"
    else
        say "!! claude-tts: cannot create $SPOOL_ROOT (run install.sh as ethan; /srv/dev is not dev-writable)"
    fi
    # dev creates the queue subtree inside it (dev-owned, group developers via setgid).
    local mk='mkdir -p "'"$SPOOL"'"/{incoming,building,failed,control,text-incoming,text-failed}
              chgrp -R developers "'"$SPOOL"'" 2>/dev/null || true
              chmod 2775 "'"$SPOOL"'" "'"$SPOOL"'"/{incoming,building,failed,control,text-incoming,text-failed}'
    "${devrun[@]}" bash -c "$mk"
    say "ethan-tier: claude-tts spool ready at $SPOOL"

    # ---- ethan side: review-gated copies from claude-tts's approved upstream ----
    if review_gate_in "$repo" "$CLAUDE_TTS_BASE_REF" "bin/tts-speak"; then
        install -D -m 0755 "$repo/bin/tts-speak" "$ETHAN_HOME/.local/bin/tts-speak"
        say "ethan-tier: installed $ETHAN_HOME/.local/bin/tts-speak"
    else
        say "   skipped tts-speak"
    fi

    local u
    for u in claude-tts-play.path claude-tts-play.service \
             claude-tts-stop.path claude-tts-stop.service; do
        if review_gate_in "$repo" "$CLAUDE_TTS_BASE_REF" "systemd/$u"; then
            install -D -m 0644 "$repo/systemd/$u" "$ETHAN_HOME/.config/systemd/user/$u"
            say "ethan-tier: installed $ETHAN_HOME/.config/systemd/user/$u"
        else
            say "   skipped $u"
        fi
    done

    # ---- enable the path watchers in ethan's user systemd ----
    if [ "$ME" = ethan ]; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now claude-tts-play.path claude-tts-stop.path \
            || say "!! could not enable claude-tts path units"
    else
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload || true
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user \
            enable --now claude-tts-play.path claude-tts-stop.path \
            || say "!! could not enable claude-tts path units as ethan (needs an active ethan session)"
    fi
    say "ethan-tier: claude-tts playback watchers wired"
}
deploy_claude_tts
