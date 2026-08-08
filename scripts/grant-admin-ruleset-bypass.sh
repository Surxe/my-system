#!/usr/bin/env bash
# Grant the Repository-admin role (i.e. Surxe, the owner) an "always" bypass on
# every branch-protection ruleset across Surxe's repos. Surxe-dev is only a Write
# collaborator, so it does NOT get the admin role and stays behind the PR gate.
#
# Run as ethan (needs an admin PAT for the Surxe account). Dry-run by default;
# pass --apply to actually PATCH the rulesets.
#
#   bash grant-admin-ruleset-bypass.sh            # show what would change
#   bash grant-admin-ruleset-bypass.sh --apply    # do it
set -euo pipefail

OWNER=Surxe
ADMIN_ROLE_ID=5          # built-in "Repository admin" role
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

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
echo

# All non-archived PUBLIC repos owned by OWNER. Private repos are skipped: on the
# free plan rulesets only apply to public repos (private ones 403 — needs Pro).
mapfile -t repos < <(gh repo list "$OWNER" --no-archived --source --visibility public \
                     --limit 500 --json name -q '.[].name' | sort)

for repo in "${repos[@]}"; do
    # Every ruleset on the repo (may be zero).
    ids=$(gh api "repos/$OWNER/$repo/rulesets" -q '.[].id' 2>/dev/null || true)
    if [ -z "$ids" ]; then
        echo "SKIP  $repo — no rulesets"
        continue
    fi

    gated_any=0
    for id in $ids; do
        rs=$(gh api "repos/$OWNER/$repo/rulesets/$id")
        # Only touch rulesets that actually enforce a PR review.
        has_pr=$(jq '[.rules[]?.type] | index("pull_request") != null' <<<"$rs")
        [ "$has_pr" = true ] || continue
        gated_any=1

        target=$(jq -r '.conditions.ref_name.include | join(",")' <<<"$rs")
        already=$(jq --argjson rid "$ADMIN_ROLE_ID" \
            '[.bypass_actors[]? | select(.actor_type=="RepositoryRole" and .actor_id==$rid)] | length > 0' <<<"$rs")

        if [ "$already" = true ]; then
            echo "OK    $repo/#$id ($target) — admin bypass already present"
            continue
        fi

        new_bypass=$(jq --argjson rid "$ADMIN_ROLE_ID" \
            '(.bypass_actors // []) + [{actor_id:$rid, actor_type:"RepositoryRole", bypass_mode:"always"}]' <<<"$rs")

        if [ "$APPLY" = 1 ]; then
            # Update ruleset = PUT (not PATCH). Don't let one failure abort the
            # whole batch — report it and move on.
            if jq -n --argjson ba "$new_bypass" '{bypass_actors:$ba}' \
                | gh api -X PUT "repos/$OWNER/$repo/rulesets/$id" --input - >/dev/null; then
                echo "DONE  $repo/#$id ($target) — added admin bypass"
            else
                echo "FAIL  $repo/#$id ($target) — update failed (see error above)" >&2
            fi
        else
            echo "WOULD $repo/#$id ($target) — add admin bypass"
        fi
    done

    [ "$gated_any" = 0 ] && echo "SKIP  $repo — has rulesets but none require PR review"
done
