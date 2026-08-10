---
name: ethan-bashrc-aliases
description: "ethan's bash dev-helper functions, refactored into ~/.bashrc.d/ modules; documented in the system-context repo"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8d64d972-1baa-46db-bb12-7dfc1bea223c
  modified: 2026-08-08T22:23:58.185Z
---

ethan's `.bashrc` carries a set of dev-helper shell **functions** (not plain aliases) for the ethan<->dev shared-repo workflow on this box:

- `devsh` — open a shell as the `dev` user, cd'd to $PWD (fallback /srv/dev)
- `devperms <dir>` — `sudo /usr/local/sbin/devperms` to fix shared perms
- `devsafe_ethan <dir>` / `devsafe_dev <dir>` — idempotently add repo to git `safe.directory` for ethan / for dev (dev via `sudo -u dev -H`)
- `devclone <profile>/<repo>` and `devnew <repo>` — clone/init under /srv/dev/repos, fix perms, mark safe for both users, then `devsh` in

Refactor plan (2026-08-07): keep shell boilerplate in `.bashrc`, add a loader that sources `~/.bashrc.d/*.sh`, split functions into `10-devsh.sh`, `20-devperms.sh`, `30-devsafe.sh`, `40-devrepo.sh`. Numeric prefixes are cosmetic — bash resolves inter-function calls at call time, so source order is irrelevant unless a file runs code at source time.

Documented in the `my-system` repo at `/srv/dev/repos/my-system/development/shell-helpers.md`. The `.bashrc.d/*.sh` sources also live in that repo at `/srv/dev/repos/my-system/users/ethan/.bashrc.d/` (dev-writable) — edit them there, then ethan deploys via `install.sh`. See [[bashrc-edit-workflow]] and [[repos-location]].
