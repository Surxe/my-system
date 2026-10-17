---
name: my-system-generated-files
description: my-system PRs can show auto-generated diffs in users/dev/sections/repo-descriptions.md; users/dev/CLAUDE.md is no longer tracked
metadata: 
  node_type: memory
  type: project
  originSessionId: 0f52b1f4-f691-44ff-979b-3c0096617093
  modified: 2026-10-17T00:00:00.000Z
---

`users/dev/CLAUDE.md` is generated and gitignored (since the untrack refactor).
It is rebuilt on every install, so it never appears in a PR.

`users/dev/sections/repo-descriptions.md` (the repo list + GitHub descriptions)
is still generated and committed. Regeneration can produce diffs unrelated to a
PR's intent.

**Why:** `build-claude-md.sh` regenerates `users/dev/CLAUDE.md` from
`CLAUDE.md.blueprint` + section files, and `scripts/generate-repo-descriptions.sh`
regenerates `sections/repo-descriptions.md`. Shared-section edits live in dev-env,
so they should never show up as diffs in my-system.

**How to apply:** Treat `repo-descriptions.md` as generated output, not
hand-edited source. Edit the blueprint or the generator scripts instead. When
reviewing a my-system PR, expect churn in that one file and don't flag it as a
stray edit. A missing dev-env builder is a hard error; there is no fallback copy.
Related: [[user-specific-via-my-system]].
