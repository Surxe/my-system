---
name: repos-location
description: "New git repos/projects go under /srv/dev/repos, not the /srv/dev root"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 605f785f-e850-49fa-988b-e3c66c0161f6
  modified: 2026-08-04T23:01:04.376Z
---

New repositories and projects should be created under `/srv/dev/repos/`, not directly in `/srv/dev`.

**Why:** `/srv/dev` root is owned by `ethan` and not writable by the `dev` user (uid 1001). `/srv/dev/repos` is group-writable (`developers` group, setgid) and is where projects belong.

**How to apply:** When starting a new repo/project, default to `/srv/dev/repos/<name>`. Don't attempt to `git init` or write files in the `/srv/dev` root — it will fail with permission denied.
