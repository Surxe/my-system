#!/bin/bash
# Apply the shared `protect-core` ruleset to an existing repo so Surxe-dev cannot
# merge without a review approval from Surxe.
#
# The ruleset itself (name, PR-review rules, admin bypass) is the SINGLE source
# of truth shared with devscaffold: /usr/local/share/devscaffold/protect-core.json,
# deployed there by install.sh. This script only computes which refs it targets --
# always ~DEFAULT_BRANCH, plus whichever of main / master / dev actually exist on
# the repo (by name, regardless of which is the default). Idempotent: an existing
# ruleset of the same name is updated in place (PUT) instead of duplicated.
#
# Must be run by ETHAN, with `gh` authenticated as `Surxe` (repo admin) -- the
# dev identity (Surxe-dev, Write collaborator) cannot create rulesets.
#
# Usage: protect-repo.sh <repo>            # e.g. protect-repo.sh todo
#        protect-repo.sh Surxe/<repo>      # owner/name also accepted
set -euo pipefail

RULESET_JSON="${PROTECT_CORE_JSON:-/usr/local/share/devscaffold/protect-core.json}"
[ -r "$RULESET_JSON" ] || {
    echo "error: cannot read $RULESET_JSON -- run install.sh to deploy it, or set" \
         "PROTECT_CORE_JSON to its path." >&2
    exit 1
}
RULESET_NAME="$(jq -r '.name' "$RULESET_JSON")"

repo="${1:-}"
[ -n "$repo" ] || { echo "usage: protect-repo.sh <repo> | <owner>/<repo>" >&2; exit 1; }
[[ "$repo" == */* ]] || repo="Surxe/$repo"

# --- auth: prefer gh's own auth; else GH_TOKEN; else lift the PAT from
#     ~/.git-credentials (this script is meant to be run BY ethan, as himself,
#     whose stored credential is the Surxe admin PAT).
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

# --- which refs to protect: always ~DEFAULT_BRANCH, plus main/master/dev when
#     that branch actually exists on the repo (by name, regardless of default).
include='["~DEFAULT_BRANCH"]'
for b in main master dev; do
    # Exact-match on the returned name: GitHub keeps branch-rename redirects
    # (e.g. a request for 'master' can 302 to 'main' and return name "main"),
    # so a bare success would wrongly report a renamed-away branch as present.
    if [ "$(gh api "repos/$repo/branches/$b" -q .name 2>/dev/null)" = "$b" ]; then
        include=$(jq -c --arg r "refs/heads/$b" '. + [$r]' <<<"$include")
        echo "note: branch '$b' exists -- protecting it by name."
    fi
done
echo "Protecting refs on ${repo}: $include"

# --- payload: shared ruleset from the canonical JSON, with only the target refs
#     overridden by the computed include list.
payload=$(jq --argjson include "$include" \
    '.conditions.ref_name.include = $include' "$RULESET_JSON")

# --- idempotent create-or-update by ruleset name.
existing_id=$(gh api "repos/$repo/rulesets" \
    -q ".[] | select(.name==\"$RULESET_NAME\") | .id" 2>/dev/null | head -n1 || true)
if [ -n "$existing_id" ]; then
    printf '%s' "$payload" \
        | gh api -X PUT "repos/$repo/rulesets/$existing_id" --input - >/dev/null
    echo "Updated existing '$RULESET_NAME' ruleset (#$existing_id) on ${repo}"
else
    new_id=$(printf '%s' "$payload" \
        | gh api -X POST "repos/$repo/rulesets" --input - -q .id)
    echo "Created '$RULESET_NAME' ruleset (#$new_id) on ${repo}"
fi
