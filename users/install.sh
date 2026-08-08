#!/usr/bin/env bash
#
# install.sh — deploy this repo's per-user + host config to their live locations.
#
# Tiers, by trust level:
#   dev-tier    users/dev/CLAUDE.md      -> ~dev/.claude/CLAUDE.md     (copy; dev's own file)
#   ethan-tier  users/ethan/.bashrc.d/*  -> ~ethan/.bashrc.d/*         (copy; runs AS ethan)
#   root-tier   system/usr-local-sbin/*  -> /usr/local/sbin/*          (sudo install, 0755)
#               system/etc-sudoers.d/*   -> /etc/sudoers.d/*           (sudo install, 0440 + visudo -c)
#
# Operator: must be run as ethan (or root). It deploys all three tiers, including
# dev's CLAUDE.md (written via sudo -u dev). Refuses for any other user. (This
# guard, plus sudo + ethan's private home, is the real boundary — file-exec perms
# in this dev-writable repo are not, since dev could `bash install.sh` regardless.)
#
# SECURITY NOTE (deliberate trade-off): privileged files are deployed by COPY from
# the local WORKING TREE, which is dev-writable. A local edit to an ethan/root file
# therefore reaches ethan/root on the next deploy — the GitHub merge gate does NOT
# cover local tampering. Mitigation: every privileged file is diffed against the
# ethan-approved `origin/master` and requires explicit confirmation before install
# (the "review gate" below). This narrows, but does not close, that window. See
# development/git-workflow.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"   # .../users
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ME="$(id -un)"
DEV_HOME="$(getent passwd dev   | cut -d: -f6)"
ETHAN_HOME="$(getent passwd ethan | cut -d: -f6)"

say(){ printf '%s\n' "$*"; }

# The ethan-approved baseline to diff privileged files against: the current
# branch's upstream, else origin/HEAD's default branch, else a sane fallback.
# (Works whether the repo's default branch is `main` or `master`.)
BASE_REF="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[ -n "$BASE_REF" ] || BASE_REF="$(git -C "$REPO_ROOT" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
[ -n "$BASE_REF" ] || BASE_REF="origin/master"

# --- review gate: privileged file must match approved upstream, else prompt.
review_gate() {   # $1 = repo-relative path
    local rel="$1"
    git -C "$REPO_ROOT" fetch -q origin 2>/dev/null || true
    if git -C "$REPO_ROOT" rev-parse --verify -q "$BASE_REF" >/dev/null; then
        if git -C "$REPO_ROOT" diff --quiet "$BASE_REF" -- "$rel"; then
            return 0   # matches ethan-approved upstream — no prompt needed
        fi
        say "!! '$rel' DIFFERS from approved $BASE_REF:"
        git -C "$REPO_ROOT" --no-pager diff "$BASE_REF" -- "$rel" || true
    else
        say "!! no upstream ($BASE_REF) to compare against yet: '$rel'"
    fi
    local a; read -r -p "   install this privileged file anyway? [y/N] " a </dev/tty
    [ "$a" = y ] || [ "$a" = Y ]
}

# --- dev-tier: dev's own CLAUDE.md (copied, not symlinked — dev already controls it) ---
deploy_dev_tier() {
    local src="$REPO_ROOT/users/dev/CLAUDE.md" dst="$DEV_HOME/.claude/CLAUDE.md"
    [ -e "$src" ] || { say "dev-tier: no $src (run users/dev/build-claude-md.sh first)"; return; }
    if [ "$ME" = dev ]; then
        install -D -m 0644 "$src" "$dst"
    else
        sudo -u dev install -D -m 0644 "$src" "$dst"
    fi
    say "dev-tier: installed (copy) $dst"
}

# --- ethan-tier: copy .bashrc.d modules into ethan's home (privileged) ---
deploy_ethan_tier() {
    local d="$ETHAN_HOME/.bashrc.d" f base rel
    for f in "$REPO_ROOT"/users/ethan/.bashrc.d/*.sh; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"; rel="users/ethan/.bashrc.d/$base"
        review_gate "$rel" || { say "   skipped $base"; continue; }
        install -D -m 0644 "$f" "$d/$base"
        say "ethan-tier: installed $d/$base"
    done
}

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
}

case "$ME" in
    ethan|root)
        say "== deploy (operator: $ME) =="
        deploy_root_tier
        deploy_ethan_tier
        deploy_dev_tier          # deploys dev's CLAUDE.md via sudo -u dev
        ;;
    *)
        say "install.sh must be run as ethan (it deploys privileged files)." >&2
        say "current user: '$ME' — refusing." >&2
        exit 1 ;;
esac
say "== done =="
