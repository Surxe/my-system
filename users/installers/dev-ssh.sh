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
                # Already a symlink; verify target
                local target; target=$(readlink "$dst" 2>/dev/null || true)
                if [ "$target" != "$src" ]; then
                    as_dev rm -f "$dst"
                    as_dev ln -s "$src" "$dst"
                fi
            else
                # File exists (or broken symlink), or doesn't exist at all.
                # Remove it if present and create the symlink.
                as_dev rm -f "$dst"
                as_dev ln -s "$src" "$dst"
                [ ! -e "$dev_ssh/$file.pre-ethan-symlink" ] || \
                    say "dev-ssh: replaced $dst with symlink to ethan's"
            fi
        fi
    done

    say "dev-tier: symlinked SSH config + keys to ethan's copy"
}

deploy_dev_ssh
