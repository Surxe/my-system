#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: symlink dev's SSH to ethan's copy (one-way read trust).
# Ethan owns the SSH for todo-hub; dev reads it via symlinks so both users can
# auth to the hub. This follows the principle: ethan owns network secrets, dev
# delegates to ethan for auth. Idempotent. ---

deploy_dev_ssh() {
    local ethan_ssh="$ETHAN_HOME/.ssh"
    local dev_ssh="$DEV_HOME/.ssh"

    # Ensure dev's .ssh exists (if it doesn't, create it; it may pre-exist with
    # other configs that aren't todo-related)
    as_dev mkdir -p "$dev_ssh"
    as_dev chmod 700 "$dev_ssh"

    # Symlink todo-related files to ethan's copy (idempotent)
    for file in config id_todo id_todo.pub; do
        local src="$ethan_ssh/$file"
        local dst="$dev_ssh/$file"

        # Only symlink if ethan's copy exists
        if [ -e "$src" ]; then
            if [ -L "$dst" ]; then
                # Already a symlink; update target if needed
                if [ "$(readlink "$dst")" != "$src" ]; then
                    as_dev rm "$dst"
                    as_dev ln -s "$src" "$dst"
                fi
            elif [ -e "$dst" ]; then
                # Exists as a file; back it up and symlink instead
                as_dev mv "$dst" "$dst.pre-ethan-symlink"
                as_dev ln -s "$src" "$dst"
                say "dev-ssh: moved $dst -> $dst.pre-ethan-symlink, symlinked to ethan's"
            else
                # Doesn't exist; create the symlink
                as_dev ln -s "$src" "$dst"
            fi
        fi
    done

    say "dev-tier: symlinked SSH config + keys to ethan's copy"
}

deploy_dev_ssh
