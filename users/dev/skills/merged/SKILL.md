---
name: merged
description: >-
  Post-merge cleanup after a /pr is merged on GitHub. Run once Ethan has merged
  the PR: closes the initiating todo, switches the local checkout back to the
  default branch, fetches and pulls, and deletes the now-merged local feature
  branch. Merge-gated and idempotent. Use whenever the user runs /merged or asks
  to clean up after a PR merged.
---

# Post-merge cleanup

The companion to `/pr`. `/pr` opens the PR and leaves the merge to Ethan; this
skill does the local cleanup afterward. It is the same-session follow-up: the PR
is opened and merged within one session, so the initiating todo id (if any) is
known from conversation — no persisted linkage.

**Safe to re-run.** Every step is idempotent, and no branch is deleted unless
GitHub confirms its PR is merged.

## Auth — same as `/pr`

`gh` is persistently authenticated for `dev` as `Surxe-dev` (via
`~/.config/gh/hosts.yml`), so call `gh` directly — no `GH_TOKEN`. If a `gh` call
fails with an auth error, re-persist from the git credential store:

```
tok=$(sed -n 's#.*://[^:]*:\([^@]*\)@.*#\1#p' ~/.git-credentials)
printf '%s' "$tok" | gh auth login --with-token
```

If the token is empty or login still fails, stop and tell Ethan.

## Step 1 — Close the initiating todo

If this session's work maps to a todo item, run it done **immediately, no
confirmation**. That mapping can arise several ways:

- the session was initiated with `!todo show <id>`;
- Ethan added the todo item at the start of the session and said to implement it;
- a todo id was referenced along the way as the thing this feature addresses.

Then:

```
todo done <id>
```

If no todo id is in play, skip this step silently. (House rule
`todo-command-no-action` says todo calls are normally Ethan's own logging and not
requests to act — this skill is the explicit exception, because closing the
initiating todo is part of what Ethan asked `/merged` to do.)

## Step 2 — Identify current and default branch

- Current branch: `git branch --show-current`.
- Default branch: `git symbolic-ref --quiet refs/remotes/origin/HEAD` (take the
  leaf after `refs/remotes/origin/`); if that is unset, fall back to
  `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.

## Step 3 — Already-clean short-circuit

If the current branch **is** the default branch, there is no feature branch to
clean. Just refresh and stop:

```
git fetch --prune
git pull --ff-only
```

Report "already on <default>, nothing to clean" and finish.

## Step 4 — Merge gate (do not skip)

Before deleting anything, confirm the feature branch's PR is actually merged:

```
gh pr view <branch> --json state,mergedAt
```

Proceed **only** if `state` is `MERGED` (mergedAt non-null). If it is not merged,
or no PR is found for the branch, **STOP** and tell Ethan — never delete unmerged
local work.

## Step 5 — Clean up

```
git switch <default>
git fetch --prune
git pull --ff-only
git branch -D <branch>
```

`--prune` drops the remote-tracking ref for the branch GitHub auto-deleted on
merge (all of Ethan's repos have delete-head-branch-on-merge on). Use `-D`, not
`-d`: the merge is already gated via GitHub, and `-d` would wrongly refuse after a
squash merge since the local commits are not ancestors of the default branch.

## Step 6 — Report

Briefly state what happened: todo closed (with id) if any, now on the default
branch, feature branch deleted, tree up to date. No emojis.
