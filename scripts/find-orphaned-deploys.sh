#!/usr/bin/env bash
#
# find-orphaned-deploys.sh — list deployed files whose repo source no longer exists.
#
# install.sh deploys by COPY and never removes anything, so a file deleted or
# renamed in the repo stays live at its destination. For .bashrc.d that is
# actively harmful: a stale function shadows a same-named command on PATH.
#
# Read-only. For each flat copy-into-dir mapping from users/install.sh, prints
# every destination entry with no matching basename in any of its source dirs.
# Destinations also receive files from outside the repos (e.g. the claude
# installer), so every hit is a CANDIDATE to review, not a verdict.
#
# Run as ethan (or root) to see ethan-tier and root-tier destinations; any
# destination the caller can't read is reported as skipped.
set -uo pipefail

REPOS=/srv/dev/repos
MS="$REPOS/my-system"
ETHAN_HOME="$(getent passwd ethan | cut -d: -f6)"
DEV_HOME="$(getent passwd dev | cut -d: -f6)"

# dest|source-dir[:source-dir...]   (sources may be single files, e.g. todo/bin/todo)
MAPPINGS=(
    "$ETHAN_HOME/.bashrc.d|$MS/users/ethan/.bashrc.d"
    "$ETHAN_HOME/.local/bin|$MS/users/ethan/localbin:$REPOS/todo/bin/todo"
    "$DEV_HOME/.bashrc.d|$MS/users/dev/.bashrc.d:$REPOS/dev-env/bashrc.d"
    "$DEV_HOME/.local/bin|$MS/users/dev/localbin:$REPOS/dev-env/bin:$REPOS/todo/bin/todo"
    "/usr/local/sbin|$MS/system/usr-local-sbin"
    "/etc/sudoers.d|$MS/system/etc-sudoers.d"
    "/etc/udev/rules.d|$MS/system/etc-udev-rules.d"
)

found=0
for m in "${MAPPINGS[@]}"; do
    dest="${m%%|*}"; IFS=: read -r -a srcs <<<"${m#*|}"
    if [ ! -r "$dest" ] || [ ! -x "$dest" ]; then
        echo "skip  $dest  (unreadable as $(id -un))" >&2; continue
    fi
    declare -A known=()
    for s in "${srcs[@]}"; do
        if [ -d "$s" ]; then
            for f in "$s"/* "$s"/.[!.]*; do [ -e "$f" ] && known["$(basename "$f")"]=1; done
        elif [ -e "$s" ]; then
            known["$(basename "$s")"]=1
        fi
    done
    for f in "$dest"/* "$dest"/.[!.]*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        b="$(basename "$f")"
        [ -n "${known[$b]:-}" ] && continue
        echo "orphan  $f"; found=$((found + 1))
    done
    unset known
done
echo "$found candidate(s)" >&2
