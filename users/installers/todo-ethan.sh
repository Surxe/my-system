#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- todo tool, ethan-tier: reviewed copy of the cross-repo todo bin -> ethan's
# ~/.local/bin (privileged). todo-capture delegates to this deployed `todo`, so
# deploy it first. Review-gated against the TODO repo's own approved upstream
# (cross-repo gate). See common.sh for TODO_REPO/TODO_BIN/TODO_BASE_REF. ---
deploy_todo_ethan() {
    [ -e "$TODO_BIN" ] || { say "todo-ethan: no $TODO_BIN — skipping"; return; }
    review_gate_in "$TODO_REPO" "$TODO_BASE_REF" "bin/todo" || { say "   skipped todo"; return; }
    install -D -m 0755 "$TODO_BIN" "$ETHAN_HOME/.local/bin/todo"
    say "ethan-tier: installed $ETHAN_HOME/.local/bin/todo"

    # ethan is not the store's owner (owner: dev), so git refuses ops there without
    # safe.directory -> ethan's captures/dones never commit and block the next pull.
    # Assert it in ethan's global git config (idempotent). See common.sh TODO_STORE.
    ensure_safe_dir "$TODO_STORE"
    say "ethan-tier: git safe.directory asserts $TODO_STORE"
}
deploy_todo_ethan
