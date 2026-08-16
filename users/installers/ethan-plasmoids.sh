#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- ethan-tier: mirror declared local Plasma widgets into ethan's home (privileged) ---
# Copies each file under users/ethan/plasmoids/** into
# ~ethan/.local/share/plasma/plasmoids/**, preserving the package layout. Mirrors
# ethan-config.sh: files are DATA (QML/JSON, 0644, no exec bit), each is
# review-gated against the approved upstream, and it is additive (never prunes).
# A newly added or updated plasmoid only registers after plasmashell restarts
# (or next login) — noted at the end.
deploy_ethan_plasmoids() {
    local root="$REPO_ROOT/users/ethan/plasmoids" f rel dest changed=0
    [ -d "$root" ] || return
    while IFS= read -r -d '' f; do
        rel="users/ethan/plasmoids/${f#"$root"/}"                       # repo-relative, for the gate
        dest="$ETHAN_HOME/.local/share/plasma/plasmoids/${f#"$root"/}"  # live target
        review_gate "$rel" || { say "   skipped ${f#"$root"/}"; continue; }
        install -D -m 0644 "$f" "$dest"
        say "ethan-tier: installed $dest"
        changed=1
    done < <(find "$root" -type f -print0)
    [ "$changed" -eq 1 ] && say "ethan-tier: plasmoids updated — restart plasmashell (or re-login) for them to register"
    return 0
}
deploy_ethan_plasmoids
