#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: mirror declared ~/.config trees into ethan's home (privileged) ---
# For plain per-user config (e.g. fastfetch/config.jsonc). Copied 0644 (data, no
# exec bit) from the dev-writable tree, so each file is review-gated like every
# other ethan-tier file. Walks users/ethan/.config/** and mirrors the path under
# it into ~ethan/.config/**, preserving subdirs; additive (never prunes files
# ethan has but the repo doesn't). Skips *.example (tracked placeholders, e.g.
# devscaffold/token.example) which are not live config.
deploy_ethan_config() {
    local root="$REPO_ROOT/users/ethan/.config" f rel dest
    [ -d "$root" ] || return
    while IFS= read -r -d '' f; do
        case "$f" in *.example) continue ;; esac
        rel="users/ethan/.config/${f#"$root"/}"          # repo-relative, for the gate
        dest="$ETHAN_HOME/.config/${f#"$root"/}"         # live target, subdirs preserved
        review_gate "$rel" || { say "   skipped ${f#"$root"/}"; continue; }
        install -D -m 0644 "$f" "$dest"
        say "ethan-tier: installed $dest"
    done < <(find "$root" -type f -print0)
}
deploy_ethan_config
