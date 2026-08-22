#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: dev's Claude Code MCP servers -> dev's live Claude config ---
# Declarative inventory: one JSON per server under users/dev/mcp/ (see its
# README for the format). Reconciles each into dev's config so a fresh machine
# gets every declared server from one install.sh run, not hand-run `claude mcp
# add` calls. Same trust model as dev's skills/memory: writes dev's OWN home
# (~dev/.claude), so no review gate.
#
# Idempotent by reconcile: `claude mcp add` ERRORS if the server already exists,
# so each entry is remove-then-add. That also redeploys definition changes.
#
# Paths in the inventory are repo-relative (portable); expanded to absolute
# against REPOS_ROOT/<repo> here because `user` scope is cwd-independent and so
# needs an absolute command. Args that look like flags (-x) pass through as-is;
# every other arg is treated as a repo-relative path and made absolute.

REPOS_ROOT="/srv/dev/repos"
INV_DIR="$REPO_ROOT/users/dev/mcp"

# Run a `claude` CLI invocation as dev: directly if we already are dev, else via
# sudo (install.sh's operator is ethan/root, but dev-tier config is dev's own).
dev_claude() {
    if [ "$ME" = dev ]; then claude "$@"; else sudo -u dev claude "$@"; fi
}

deploy_dev_mcp() {
    [ -d "$INV_DIR" ] || { say "dev-mcp: no $INV_DIR — skipping"; return; }
    shopt -s nullglob
    local f
    for f in "$INV_DIR"/*.json; do
        local name repo cmd scope repo_root abs_cmd a
        name="$(jq -r '.name'          "$f")"
        repo="$(jq -r '.repo'          "$f")"
        cmd="$(jq -r '.command'        "$f")"
        scope="$(jq -r '.scope // "user"' "$f")"
        [ -n "$name" ] && [ "$name" != null ] || { say "dev-mcp: $f has no .name — skipping"; continue; }
        repo_root="$REPOS_ROOT/$repo"
        abs_cmd="$repo_root/$cmd"

        # Expand args: repo-relative paths -> absolute; leave flags (-x) alone.
        local -a args=()
        while IFS= read -r a; do
            case "$a" in
                -*) args+=("$a") ;;
                *)  args+=("$repo_root/$a") ;;
            esac
        done < <(jq -r '.args[]?' "$f")

        # Reconcile (idempotent): drop any existing definition, then re-add.
        dev_claude mcp remove "$name" --scope "$scope" >/dev/null 2>&1 || true
        dev_claude mcp add "$name" --scope "$scope" -- "$abs_cmd" "${args[@]}" >/dev/null
        say "dev-tier: registered MCP '$name' ($scope) -> $abs_cmd ${args[*]}"
    done
}
deploy_dev_mcp
