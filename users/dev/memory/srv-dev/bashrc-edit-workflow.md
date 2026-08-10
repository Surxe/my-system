---
name: bashrc-edit-workflow
description: "How to edit ethan's bashrc.d helpers: edit in the my-system repo (dev-writable), then ask before commit + remind to run install.sh"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a1caf976-265a-496d-8937-b9a637d4d6aa
  modified: 2026-08-08T22:23:52.811Z
---

Ethan's `.bashrc.d/*.sh` dev-helper functions are edited **in the repo**, not in ethan's home. The source of truth is `/srv/dev/repos/my-system/users/ethan/.bashrc.d/` (owner dev / group developers, so dev — me — can edit directly). A separate install step deploys them into ethan's live home, which dev cannot write.

**Why:** the files under the repo are dev-writable, but the live `~/.bashrc.d/` in ethan's home is not — so edits land in the repo and ethan deploys them. This supersedes the older belief in [[ethan-bashrc-aliases]] that dev couldn't touch these at all.

**How to apply:** after editing any of these files, do NOT auto-commit. Just ask Ethan whether he wants the changes committed, and remind him to run `install.sh` (at `/srv/dev/repos/my-system/users/`) to deploy them into his home. No need to paste the command into chat.
