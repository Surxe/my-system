# Git workflow

- Repositories live under `/srv/dev/repos`.
- Use branches; use pull requests where appropriate.
- The default branch for repos is `master`.
- Claude may help create code and commits, but **avoid automatic destructive
  actions**. Commit / push only when asked.

## Two git identities, one purpose split

Both identities push to the **same GitHub-owned repos** (`Surxe`), but with
different GitHub *accounts* and *tokens* so their capabilities differ. Capability
differences are enforced by GitHub (account + branch rulesets), **not** by token
scopes — a classic PAT's scopes cannot express "no force-push" or "no merge".

| Identity | GitHub account | Token | Can | Cannot |
| --- | --- | --- | --- | --- |
| `ethan` (primary) | `Surxe` | classic PAT, wide scopes; stored in ethan's own home | everything, incl. approve + merge PRs, direct pushes | — |
| `dev` (automation) | `Surxe-dev` (separate account, `Write` collaborator) | classic PAT, `repo` scope only; `~/.git-credentials` (chmod 600) | create branches, push feature branches, open/edit PRs | force-push `master`, delete `master`, **approve or merge PRs** |

- **Why a second account, not just a second token:** GitHub evaluates branch
  protection against the *account (actor)*, not the token. Two tokens of the same
  account are indistinguishable, so "dev can't merge but ethan can" is only
  possible with a distinct account.
- **Merge gate:** rulesets on `master` require a PR + 1 approval. dev authors its
  PRs as `Surxe-dev` and cannot approve its own PR, so only `ethan` (a different
  actor) can approve — nothing merges without ethan's sign-off.
  - Fully airtight "dev cannot click merge even after approval" additionally
    needs *Restrict who can push to matching branches → ethan only*, which on
    private personal repos requires **GitHub Pro**.

### Merge gate on a free plan (current reality)

This account is on the **free** plan, where **rulesets / branch protection only
apply to public repos** — private repos return HTTP 403 ("Upgrade to GitHub Pro or
make this repository public"). Consequences:

- **Public repos:** the ruleset applies, the merge gate above holds in full.
- **Private repos:** **no server-side gate exists.** `Surxe-dev`'s `Write`
  collaborator access is unconstrained — it can push directly to `master`, merge
  its own PRs, force-push, and delete branches. The two-identity split degrades to
  *convention* here, not enforcement.

Chosen posture (2026-08-08): **best-effort ruleset, default public.** `devrepo new`
(and `devscaffold`) create **public** repos by default, so the merge gate applies;
pass `--private` to opt into a private repo, which on the free plan has no enforced
gate. On 403 `devscaffold` warns and continues so the repo + collaborator still get
created (no orphan repos). Revisit via GitHub Pro or the fork model if enforced
gating on private repos becomes necessary.

## `master` ruleset (per repo)

Settings → Rules → Rulesets, target branch `master`. `devscaffold` (below)
applies this automatically via `gh api` on a **best-effort** basis — see
"Merge gate on a free plan" above for why it silently no-ops on private repos:

- Require a pull request before merging
- Require approvals: 1
- Block force pushes
- Restrict deletions
- Bypass list: empty (the dev account is **not** exempt)

## Authentication

- HTTPS + classic PAT via `credential.helper store` (`~/.git-credentials`,
  `chmod 600`). One classic PAT per identity authenticates that identity to every
  repo it collaborates on. This supersedes the earlier "SSH preferred" note.
- **Never** embed a PAT in a remote URL — remotes are plain
  `https://github.com/Surxe/<repo>.git`. Secrets policy in
  [../private/secrets-policy.md](../private/secrets-policy.md).

## Programmatic repo scaffolding (`devscaffold`)

> The `devscaffold` wrapper and its sudoers rule shown below are **live on disk but
> not yet version-controlled** — the code blocks here are the de-facto source of
> truth. Tracked in [uncommitted-artifacts.md](uncommitted-artifacts.md).


`devrepo new`/`devrepo clone` ([shell-helpers.md](shell-helpers.md)) can be driven from
`dev`-context automation (scripts, Claude). The catch: creating a repo under
`Surxe`, adding `Surxe-dev` as a collaborator, and applying the ruleset all
require **ethan's** PAT — but `Surxe-dev`'s constrained token deliberately can't
do them. We must let a `dev`-context caller trigger *only* those account-side
actions with ethan's creds, **without** making ethan's PAT ambiently available to
everything running as `dev`.

**Anti-pattern (rejected):** giving `dev` a `credential.helper` (or env-gated
helper, or a copy of the token in a dev-readable file) that can emit ethan's PAT.
Any such path means *every* `dev` process effectively **is** ethan, collapsing the
two-identity split above.

**Design:** a single root-owned wrapper, invokable by `dev` as `ethan` through one
narrow `sudo` rule. It performs only GitHub-*account* actions and writes **nothing**
under `/srv/dev`; once the empty remote exists and `Surxe-dev` is a collaborator,
all local git (clone/init/commit/push) runs as the ordinary `dev` identity with the
dev PAT. Ethan's PAT therefore never touches the filesystem tree and there is no
ambient auth to leak.

Adding `Surxe-dev` as a collaborator on a personal repo creates a **pending
invitation** it must accept before its PAT can push. That acceptance can only be
performed by the invitee, so it happens on the dev side via `devaccept`
([shell-helpers.md](shell-helpers.md)) — not in `devscaffold`.

| Property | How it's met |
| --- | --- |
| ethan's creds usable programmatically | `sudo -u ethan devscaffold`, callable from dev-context |
| **not** ambient across `/srv/dev` | ethan-context process writes nothing under the tree |
| minimal privilege | one fixed program, strict arg validation, account-side actions only |
| auditable | every use is a sudo log line |

### `/usr/local/sbin/devscaffold` (root-owned, `0755`)

```bash
#!/bin/bash
# GitHub-side repo scaffolding as ethan. Creates the remote, grants the dev
# account push access, and applies the master ruleset. Touches NOTHING under
# /srv/dev — all local git work is done afterwards by the `dev` identity.
set -euo pipefail
export PATH=/usr/bin:/bin
export HOME=/home/ethan
export GIT_TERMINAL_PROMPT=0          # never prompt; fail closed

OWNER=Surxe
DEVACCT=Surxe-dev
BRANCH=master

usage(){ echo "usage: devscaffold <reponame> [--private|--public]" >&2; exit 2; }

name="${1:-}"; vis="public"           # default public (free-plan merge gate works)
case "${2:-}" in
    ""|--public) vis="public"  ;;
    --private)   vis="private" ;;
    *) usage ;;
esac
[ -n "$name" ] || usage
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$ ]] || { echo "bad repo name" >&2; exit 1; }
[[ "$name" == *..* ]] && { echo "bad repo name" >&2; exit 1; }

if gh repo view "$OWNER/$name" >/dev/null 2>&1; then
    echo "already exists on GitHub: $OWNER/$name" >&2; exit 1
fi

# 1. create empty remote (no branches yet). Use the REST endpoint, NOT
#    `gh repo create` — the latter goes through the GraphQL createRepository
#    mutation, which demands full `repo` scope even for public repos. REST
#    `POST /user/repos` honors the minimal `public_repo` scope for public repos.
priv=false; [ "$vis" = private ] && priv=true
gh api -X POST /user/repos -f name="$name" -F private="$priv" >/dev/null

# 2. grant the dev automation account push (Write) access
gh api -X PUT "repos/$OWNER/$name/collaborators/$DEVACCT" -f permission=push >/dev/null

# 3. BEST-EFFORT: apply the master ruleset (PR+1 approval, no force-push, no
#    deletion). On a FREE plan rulesets only work on PUBLIC repos; a private repo
#    returns 403 ("Upgrade to GitHub Pro..."). We warn and continue rather than
#    abort, so the repo + collaborator (steps 1-2) still stand and no orphan is
#    left behind. WARNING: a private repo scaffolded this way has NO server-side
#    merge gate — Surxe-dev's Write access is unconstrained (it can push, merge,
#    force-push, and delete master). See "Merge gate on a free plan" below.
if ! gh api -X POST "repos/$OWNER/$name/rulesets" --input - >/dev/null 2>&1 <<JSON
{
  "name": "protect-$BRANCH",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/$BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      } }
  ]
}
JSON
then
    echo "warning: could not apply $BRANCH ruleset — no server-side merge gate" \
         "on this repo (free plan private repos need GitHub Pro)" >&2
fi

echo "https://github.com/$OWNER/$name.git"   # plain remote URL only
```

Install:

```bash
sudo install -o root -g root -m 0755 devscaffold /usr/local/sbin/devscaffold
```

### `/etc/sudoers.d/devscaffold` (`0440`)

The entire dev→ethan bridge — `dev` may run *only* this fixed program as ethan:

```
dev ALL=(ethan) NOPASSWD: /usr/local/sbin/devscaffold
```

`sudo`'s `env_reset` (default) strips dev-supplied `GIT_CONFIG`, `HOME`,
`LD_PRELOAD`, `PATH`, etc.; the script re-asserts `HOME`/`PATH` regardless.
Argument freedom is bounded by the script being fixed, arg-validated code that only
creates repos — the same trust model as `devperms` trusting its path check.
Validate after install with `sudo visudo -c`.

### Token scopes for `devscaffold`

The token `devscaffold` authenticates with (keyring, or the `GH_TOKEN` file below)
needs, at minimum:

- **Public default path:** classic **`public_repo`** — covers REST repo create +
  collaborator add + ruleset on public repos.
- **`--private` path:** classic **`repo`** (no finer classic scope grants
  private-repo admin).
- Do **not** grant `repo:invite` here — accepting invites is the dev side
  (`devaccept`); this token only *creates* the invite.

Gotcha: `gh repo create` uses the GraphQL `createRepository` mutation, which
requires full `repo` even for public repos — that's why step 1 uses the REST
`POST /user/repos` endpoint instead, which respects `public_repo`.

### Hardening: dedicated fine-grained PAT (recommended follow-up)

The baseline uses ethan's wide classic PAT. To shrink blast radius, mint a
**fine-grained PAT** scoped to only `Administration: read/write` +
collaborator/members management on the `Surxe` account, store it in a root-owned
file, and have `devscaffold` load it (e.g. `export GH_TOKEN=$(cat /root/…)`)
instead of ethan's store. A breach of the wrapper then leaks a token that can
*only* create repos and add the known collaborator — never read code, merge, or
delete. Secrets policy: [../private/secrets-policy.md](../private/secrets-policy.md).
