---
name: memory-files-edit-in-repo
description: Writing/editing ANY Claude memory file → edit the repo copy in my-system (users/dev/memory/<proj>/), never the live ~/.claude copy; deploy via install.sh
metadata:
  type: feedback
---

Claude memory files (both the individual `<slug>.md` notes and `MEMORY.md`) are
**source-controlled in my-system**, not authored in the live store. The source of
truth is `/srv/dev/repos/my-system/users/dev/memory/<proj>/` (e.g. `srv-dev/` for
the `/srv/dev` project). `users/install.sh` (`deploy_dev_memory`) does an additive
copy into the live path `~dev/.claude/projects/-<proj>/memory/`.

**Why:** the repo copy is dev-writable and reviewed; the live `~/.claude` dir is the
deploy target and carries the verification/consent boundary. Writing straight to
live bypasses that boundary and drifts from the source of truth — same principle as
[[bashrc-edit-workflow]] and [[no-symlink-repo-to-home]].

**How to apply:** the moment you are about to create or edit ANY memory file —
including in response to an explicit "add a memory" request — write it under
`users/dev/memory/<proj>/` in the repo, add its index line to that dir's
`MEMORY.md`, and do NOT touch the live `~/.claude/.../memory/` copies. Do not
auto-commit; ask Ethan, then remind him to run `install.sh` to deploy. This is the
*where-to-write* rule; [[no-auto-memory-without-consent]] is the separate
*whether-to-write* rule — satisfying consent does NOT exempt you from this.
