#!/usr/bin/env bash
# Create a branch ruleset on ONE of Surxe's repos that requires every change to
# the default branch to go through a pull request with at least one approving
# review. Surxe-dev is only a Write collaborator, so this gates it: it can open
# PRs but cannot merge them without an approval from Surxe (GitHub never lets an
# author approve their own PR). Surxe (the Repository-admin role) gets an
# "always" bypass so the owner can still merge directly — mirroring the sibling
# script grant-admin-ruleset-bypass.sh.
#
# Run as ethan (needs an admin PAT for the Surxe account). Dry-run by default;
# pass --apply to actually create the ruleset.
#
#   bash require-pr-review-ruleset.sh <repo>            # show what would happen
#   bash require-pr-review-ruleset.sh <repo> --apply    # create it
set -euo pipefail

OWNER=Surxe
ADMIN_ROLE_ID=5              # built-in "Repository admin" role (i.e. Surxe)
RULESET_NAME="require-pr-review"
REQUIRED_APPROVALS=1

# --- args
REPO=""
APPLY=0
for arg in "$@"; do
    case "$arg" in
        --apply) APPLY=1 ;;
        -*)      echo "error: unknown option '$arg'" >&2; exit 2 ;;
        *)       [ -z "$REPO" ] && REPO="$arg" || { echo "error: only one repo may be given" >&2; exit 2; } ;;
    esac
done
if [ -z "$REPO" ]; then
    echo "usage: $(basename "$0") <repo> [--apply]" >&2
    exit 2
fi

# --- auth: prefer gh's own auth; else GH_TOKEN; else lift ethan's PAT from
#     ~/.git-credentials (this script is meant to be run BY ethan, as himself).
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
echo "Authenticated as: $(gh api user -q .login)"
[ "$APPLY" = 1 ] && echo "MODE: APPLY" || echo "MODE: dry-run (pass --apply to change anything)"
echo "Target: $OWNER/$REPO"
echo

# --- confirm the repo exists and we can see it.
gh api "repos/$OWNER/$REPO" -q .full_name >/dev/null 2>&1 || {
    echo "error: cannot access repo $OWNER/$REPO (wrong name, or token lacks access)." >&2
    exit 1
}

# --- idempotency: bail if a ruleset with our name is already there.
existing_id=$(gh api "repos/$OWNER/$REPO/rulesets" \
    -q ".[] | select(.name==\"$RULESET_NAME\") | .id" 2>/dev/null || true)
if [ -n "$existing_id" ]; then
    echo "OK    ruleset '$RULESET_NAME' already exists (#$existing_id) — nothing to do."
    exit 0
fi

# --- which refs to gate: always the default branch (via the ~DEFAULT_BRANCH
#     alias, so we never hardcode 'main' vs 'master'), plus 'dev' if that branch
#     actually exists on the repo.
include_json='["~DEFAULT_BRANCH"]'
if gh api "repos/$OWNER/$REPO/branches/dev" -q .name >/dev/null 2>&1; then
    include_json='["~DEFAULT_BRANCH","refs/heads/dev"]'
    echo "note: 'dev' branch exists — it will be gated too."
else
    echo "note: no 'dev' branch — gating the default branch only."
fi
echo

# --- ruleset payload. require_last_push_approval means the person who pushed the
#     newest commit can't be the sole approver, so Surxe-dev cannot
#     push-then-self-approve its way around the gate.
payload=$(jq -n \
    --arg name "$RULESET_NAME" \
    --argjson approvals "$REQUIRED_APPROVALS" \
    --argjson admin "$ADMIN_ROLE_ID" \
    --argjson include "$include_json" '
{
  name: $name,
  target: "branch",
  enforcement: "active",
  conditions: { ref_name: { include: $include, exclude: [] } },
  rules: [
    {
      type: "pull_request",
      parameters: {
        required_approving_review_count: $approvals,
        dismiss_stale_reviews_on_push: true,
        require_code_owner_review: false,
        require_last_push_approval: true,
        required_review_thread_resolution: false
      }
    }
  ],
  bypass_actors: [
    { actor_id: $admin, actor_type: "RepositoryRole", bypass_mode: "always" }
  ]
}')

if [ "$APPLY" = 1 ]; then
    new_id=$(printf '%s' "$payload" \
        | gh api -X POST "repos/$OWNER/$REPO/rulesets" --input - -q .id)
    echo "DONE  created ruleset '$RULESET_NAME' (#$new_id) on $OWNER/$REPO"
    echo "      default branch now needs $REQUIRED_APPROVALS approving review to merge;"
    echo "      Surxe (admin) bypasses, Surxe-dev (Write) is gated."
else
    echo "WOULD create ruleset '$RULESET_NAME' on $OWNER/$REPO:"
    printf '%s\n' "$payload"
fi
