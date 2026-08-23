#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: clip-db Discord post queue (spool + watcher wiring) ---
# The drain script (clip-discord-drain) and the two systemd USER units
# (clip-discord-watch.path/.service, under users/ethan/.config/systemd/user) are
# already deployed by ethan-bin / ethan-config above. This step does the two things
# those generic copies can't:
#   (a) create the shared spool dir the MCP (dev) writes and the watcher (ethan) reads,
#       owned by dev, group-writable + setgid so both users can drop/move jobs;
#   (b) reload + enable the path unit in Ethan's user systemd.
#
# Why a spool at all: the MCP runs as dev and can't read the ethan-owned webhook secret,
# so dev prepares the clip and queues a job here, and this ethan-side watcher posts it.
QUEUE_DIR="/srv/dev/clips/discord-queue"

deploy_clip_discord() {
    local uid; uid="$(id -u ethan)"

    # (a) spool dir -- owned by dev (it lives under dev's /srv/dev/clips). Create it AS
    # dev so ownership is right, setgid + group-writable so the ethan watcher can move
    # jobs between incoming/ -> sent/ | failed/.
    local mk='mkdir -p "'"$QUEUE_DIR"'"/incoming "'"$QUEUE_DIR"'"/sent "'"$QUEUE_DIR"'"/failed
              chgrp -R developers "'"$QUEUE_DIR"'" 2>/dev/null || true
              chmod 2775 "'"$QUEUE_DIR"'" "'"$QUEUE_DIR"'"/incoming "'"$QUEUE_DIR"'"/sent "'"$QUEUE_DIR"'"/failed'
    if [ "$ME" = dev ]; then
        bash -c "$mk"
    else
        sudo -u dev bash -c "$mk"
    fi
    say "ethan-tier: clip-db Discord spool ready at $QUEUE_DIR"

    # (b) reload + enable the path watcher in ethan's user systemd.
    if [ "$ME" = ethan ]; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now clip-discord-watch.path \
            || say "!! could not enable clip-discord-watch.path"
    else
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload || true
        sudo -u ethan XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user \
            enable --now clip-discord-watch.path \
            || say "!! could not enable clip-discord-watch.path as ethan (needs an active ethan session)"
    fi
    say "ethan-tier: clip-db Discord queue watcher wired"
}
deploy_clip_discord
