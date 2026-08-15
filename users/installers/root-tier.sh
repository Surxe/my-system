#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- root-tier: host scripts + sudoers drop-ins (need root) ---
deploy_root_tier() {
    local f base rel tmp
    for f in "$REPO_ROOT"/system/usr-local-sbin/*; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="system/usr-local-sbin/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        sudo install -o root -g root -m 0755 "$f" "/usr/local/sbin/$base"
        say "root-tier: installed /usr/local/sbin/$base"
    done
    for f in "$REPO_ROOT"/system/etc-sudoers.d/*; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="system/etc-sudoers.d/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        tmp="$(mktemp)"; install -m 0440 "$f" "$tmp"
        if sudo visudo -cf "$tmp" >/dev/null; then
            sudo install -o root -g root -m 0440 "$f" "/etc/sudoers.d/$base"
            say "root-tier: installed /etc/sudoers.d/$base (validated)"
        else
            say "!! REFUSED /etc/sudoers.d/$base — visudo -c failed; left unchanged"
        fi
        rm -f "$tmp"
    done
    # world-readable host data (the shared protect-core ruleset consumed by
    # devscaffold + protect-repo.sh, and the merge-policy definition consumed by
    # devscaffold + set-merge-policy.sh); mirrors the repo path under
    # system/usr-local-share/ into /usr/local/share/ preserving subdirs.
    if [ -d "$REPO_ROOT"/system/usr-local-share ]; then
        while IFS= read -r -d '' f; do
            rel="${f#"$REPO_ROOT"/}"                       # e.g. system/usr-local-share/devscaffold/x.json
            dest="/usr/local/share/${rel#system/usr-local-share/}"
            review_gate "$rel" || { say "   skipped $rel"; continue; }
            sudo install -o root -g root -m 0644 -D "$f" "$dest"
            say "root-tier: installed $dest"
        done < <(find "$REPO_ROOT"/system/usr-local-share -type f -print0)
    fi
}
deploy_root_tier
