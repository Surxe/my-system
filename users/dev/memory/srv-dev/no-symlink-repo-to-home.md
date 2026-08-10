---
name: no-symlink-repo-to-home
description: "never symlink dev-writable repo files into Ethan's home; install.sh must COPY"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 03c34e0b-7f33-4f3c-94a9-28da92624584
  modified: 2026-08-09T05:40:24.184Z
---

Never create a symlink from a dev-writable repo (e.g. [[repos-location]] under /srv/dev/repos, like my-system) into Ethan's home directory. When install.sh needs to expose a repo script at a home path (e.g. ~/.local/bin/todo), it must **copy** the file, never symlink it.

**Why:** the dev user can write those repos. A live symlink from home into a dev-writable repo would let dev-authored, unverified code execute in Ethan's home context (as Ethan) without any review step. A copy forces re-running install.sh, which keeps a verification/consent boundary between "code changed in the repo" and "code runs as Ethan."

**How to apply:** in install.sh and any similar wiring, use copy (source-of-truth stays in the repo, copy lands in home). After editing a repo script, remind Ethan to re-run install.sh to sync the copy — same shape as [[bashrc-edit-workflow]]. Do not propose symlink-based install steps.
