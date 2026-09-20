#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: ethan's SSH config and keys for todo-hub (home-server).
# Ethan owns the SSH (one-way trust: dev reads ethan's keys, not vice versa).
# Deployed as a COPY (never symlinks) from users/ethan/.ssh into ~ethan/.ssh.
# Dev symlinks to ethan's copy so it can auth to the hub. Idempotent. ---

deploy_ethan_ssh() {
    local srcdir="$REPO_ROOT/users/ethan/.ssh"
    local dstdir="$ETHAN_HOME/.ssh"

    if [ ! -d "$srcdir" ]; then
        say "ethan-ssh: no $srcdir — skipping"; return
    fi

    # Create ethan's .ssh with secure perms
    [ -d "$dstdir" ] || mkdir -p "$dstdir"
    chmod 700 "$dstdir"

    # Deploy SSH files (COPY, not symlink)
    for file in config id_todo id_todo.pub; do
        if [ -e "$srcdir/$file" ]; then
            install -m 600 "$srcdir/$file" "$dstdir/$file"  # keys are 600
        fi
    done
    chmod 644 "$dstdir/config" "$dstdir/id_todo.pub" 2>/dev/null || true

    say "ethan-tier: installed SSH config + keys -> $dstdir"
}

deploy_ethan_ssh
