---
name: my-system-generated-files
description: my-system PRs often show auto-generated diffs in users/dev/CLAUDE.md and sections/repo-descriptions.md
metadata: 
  node_type: memory
  type: project
  originSessionId: 0f52b1f4-f691-44ff-979b-3c0096617093
  modified: 2026-08-14T05:19:58.358Z
---

PRs to the my-system repo will often surface auto-generated data in
`users/dev/CLAUDE.md` and `users/dev/sections/repo-descriptions.md` (the repo
list + GitHub descriptions).

**Why:** `build-claude-md.sh` regenerates `users/dev/CLAUDE.md` from
`CLAUDE.md.blueprint` + section files, and `scripts/generate-repo-descriptions.sh`
regenerates `sections/repo-descriptions.md`. Both are committed (not gitignored),
so any run — including a deploy — can produce diffs unrelated to the PR's intent.

**How to apply:** Treat those two files as generated output, not hand-edited
source. Edit the blueprint or the generator scripts instead. When reviewing a
my-system PR, expect churn in them and don't flag it as a stray edit. The
"Last generated" date comment was removed from the generator so regeneration no
longer produces spurious timestamp-only diffs. Related: [[user-specific-via-my-system]].
