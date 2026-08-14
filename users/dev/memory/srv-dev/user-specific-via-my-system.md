---
name: user-specific-via-my-system
description: "new skills/aliases/shortcuts/statusbars/memory files/anything user-specific goes in my-system + wired into install.sh, never edited in user files directly"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: eab1e646-b718-4eff-ba5a-a0648004d63b
  modified: 2026-08-10T04:16:16.696Z
---

New **skills, shell aliases/functions, desktop shortcuts, status bars, or anything user-specific** are authored in the **my-system** repo (`/srv/dev/repos/my-system`) and wired into `install.sh` — never created or edited directly in the user's live files (`~/.claude/`, `~/.bashrc.d/`, etc.).

Known repo locations: Claude skills live under `users/dev/skills/<name>/SKILL.md`; Claude memory files under `users/dev/memory/<project>/` (e.g. `srv-dev/`) — see [[memory-files-edit-in-repo]]; shell helpers under `users/ethan/.bashrc.d/`; desktop launchers under `users/ethan/desktop-entries/`. The deployer is `/srv/dev/repos/my-system/users/install.sh`.

**Why:** the repo is dev-writable and reviewed; the live home files are the deploy target and carry a verification/consent boundary. Editing home directly bypasses that boundary and drifts from the source of truth. Same principle as [[bashrc-edit-workflow]] and [[no-symlink-repo-to-home]], generalized to all user-specific artifacts.

**How to apply:** author/edit in the my-system repo, make sure install.sh covers the new artifact, then remind Ethan to run `install.sh` to deploy (copy, never symlink). Do not auto-commit — ask first, per [[bashrc-edit-workflow]].
