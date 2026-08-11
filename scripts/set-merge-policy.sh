#!/bin/bash
# Apply the shared repo merge policy to an existing Surxe repo: squash-only merges
# (no merge commits, no rebase) and auto-delete the head branch on merge, with the
# PR title/body used as the squash commit text.
#
# The policy itself is the SINGLE source of truth shared with devscaffold:
# /usr/local/share/devscaffold/merge-policy.json, deployed there by install.sh.
# devscaffold seeds it into `POST /user/repos` at creation; this script PATCHes the
# same fields onto a repo created some other way (e.g. via the GitHub UI). Both
# read the one JSON, so there is no second copy of the policy to drift. Idempotent:
# PATCH just re-asserts the same settings.
#
# Must be run by ETHAN, with `gh` authenticated as `Surxe` (repo admin) -- the dev
# identity (Surxe-dev, Write collaborator) cannot change repo settings.
#
# Usage: set-merge-policy.sh <repo>            # e.g. set-merge-policy.sh todo
#        set-merge-policy.sh Surxe/<repo>      # owner/name also accepted
set -euo pipefail

POLICY_JSON="${MERGE_POLICY_JSON:-/usr/local/share/devscaffold/merge-policy.json}"
[ -r "$POLICY_JSON" ] || {
    echo "error: cannot read $POLICY_JSON -- run install.sh to deploy it, or set" \
         "MERGE_POLICY_JSON to its path." >&2
    exit 1
}

repo="${1:-}"
[ -n "$repo" ] || { echo "usage: set-merge-policy.sh <repo> | <owner>/<repo>" >&2; exit 1; }
[[ "$repo" == */* ]] || repo="Surxe/$repo"

# --- auth: prefer gh's own auth; else GH_TOKEN; else lift the PAT from
#     ~/.git-credentials (this script is meant to be run BY ethan, as himself,
#     whose stored credential is the Surxe admin PAT). Mirrors protect-repo.sh.
if ! gh auth status >/dev/null 2>&1 && [ -z "${GH_TOKEN:-}" ]; then
    if [ -r "$HOME/.git-credentials" ]; then
        tok=$(grep -m1 '@github\.com' "$HOME/.git-credentials" \
              | sed -E 's#https://[^:]*:([^@]+)@.*#\1#') || true
        [ -n "${tok:-}" ] && export GH_TOKEN="$tok"
    fi
fi
gh api user -q .login >/dev/null 2>&1 || {
    echo "error: gh is not authenticated. Run 'gh auth login' or export GH_TOKEN." >&2
    exit 1
}

echo "Applying merge policy to ${repo}:"
jq -r 'to_entries[] | "  \(.key) = \(.value)"' "$POLICY_JSON"

gh api -X PATCH "repos/$repo" --input "$POLICY_JSON" >/dev/null
echo "Merge policy applied to ${repo}"
