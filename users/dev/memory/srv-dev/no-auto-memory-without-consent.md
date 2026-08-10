---
name: no-auto-memory-without-consent
description: Ethan wants to approve every memory; never auto-write — suggest instead
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d55bdc29-5c8e-4804-a5cc-5fd035ca7507
  modified: 2026-08-08T02:16:21.964Z
---

Ethan does not want Claude adding memories without his input. Do not autonomously create or edit memory files.

**Why:** Ethan wants to be the sole manager of his memory store and curate what persists across sessions.

**How to apply:** Any time you would normally create or update an auto-memory, do NOT write it. Instead, describe the memory you'd propose (name, type, content) and let Ethan decide. Only write to the memory dir when he explicitly asks. This preference itself was added at his explicit request.

**Where to edit:** Memory files are versioned in `my-system` at `users/dev/memory/<project>/` (e.g. `srv-dev/` for the `/srv/dev` project) and deployed to the live `~/.claude/projects/*/memory/` dirs by `users/install.sh`. When Ethan does approve a memory change, **edit the repo copy there and re-run `install.sh`** — do NOT edit the live copies directly, since the next deploy (repo-authoritative `cp -a`) overwrites them. Same workflow as [[bashrc-edit-workflow]]; see also [[user-specific-via-my-system]].
