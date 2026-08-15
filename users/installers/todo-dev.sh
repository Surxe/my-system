#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- todo tool, dev-tier: dev's own copy (dev controls its home — no gate). ---
# See common.sh for the shared TODO_REPO/TODO_BIN locations and trust model.
deploy_todo_dev() {
    [ -e "$TODO_BIN" ] || { say "todo-dev: no $TODO_BIN — skipping"; return; }
    if [ "$ME" = dev ]; then
        install -D -m 0755 "$TODO_BIN" "$DEV_HOME/.local/bin/todo"
    else
        sudo -u dev install -D -m 0755 "$TODO_BIN" "$DEV_HOME/.local/bin/todo"
    fi
    say "dev-tier: installed $DEV_HOME/.local/bin/todo"
}
deploy_todo_dev
