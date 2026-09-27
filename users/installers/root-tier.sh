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
            warn "REFUSED /etc/sudoers.d/$base — visudo -c failed; left unchanged"
        fi
        rm -f "$tmp"
    done
    # udev rules (e.g. hidraw access for razer-battery). Installed 0644 root; if
    # any rule actually changed, reload + retrigger so the grant applies to the
    # already-plugged device without a replug.
    local udev_changed=0
    if [ -d "$REPO_ROOT"/system/etc-udev-rules.d ]; then
        for f in "$REPO_ROOT"/system/etc-udev-rules.d/*; do
            [ -e "$f" ] || continue
            base="$(basename "$f")"; rel="system/etc-udev-rules.d/$base"
            review_gate "$rel" || { say "   skipped $base"; continue; }
            if sudo cmp -s "$f" "/etc/udev/rules.d/$base" 2>/dev/null; then
                say "root-tier: /etc/udev/rules.d/$base already current"
                continue
            fi
            sudo install -o root -g root -m 0644 "$f" "/etc/udev/rules.d/$base"
            say "root-tier: installed /etc/udev/rules.d/$base"
            udev_changed=1
        done
    fi
    if [ "$udev_changed" = 1 ]; then
        sudo udevadm control --reload-rules
        sudo udevadm trigger --subsystem-match=hidraw --action=add
        say "root-tier: reloaded udev rules and retriggered hidraw"
    fi

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
