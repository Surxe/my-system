---
name: secrets-for-dev-run-tools
description: "secrets for a dev-run tool live in ethan's space (dev can't read at rest), injected via an ethan launcher — never parked in ~dev"
metadata:
  node_type: memory
  type: feedback
  originSessionId: cf52e605-15e7-4e2c-aced-c8e7b7c21091
  modified: 2026-08-22T00:00:00.000Z
---

For a tool whose pipeline runs AS `dev` but needs secrets (API tokens, passwords, PATs), do NOT store the secret file where `dev` can read it (e.g. `~dev/.config/...`). Put it in Ethan's space, mode 600, ethan-owned — the same shape as `~ethan/.config/steam-price-tracker/smtp.env` — and inject the values into the `dev` run at launch via an ethan-owned launcher (`sudo -u dev --preserve-env=VAR1,VAR2 ...`). The repo ships only a `secrets.env.example`; the real file is hand-maintained by Ethan. See the `wrf-orchestrator` launcher and the WRFrontiersDB-Orchestrator repo for the reference implementation.

**Why:** `dev` is the repo-writable, AI-touched account ([[no-symlink-repo-to-home]], [[github-auth-as-dev]]). If secrets sit in `~dev`, any dev-tree code (or an AI action as dev) can read them at rest — the exact account the boundary is meant to contain. Keeping the file ethan-owned means a `dev` compromise yields nothing at rest; the secrets exist only transiently in the launched process's environment.

**How to apply:** secret file → `~ethan/.config/<tool>/secrets.env` (chmod 600, hand-maintained), documented by location only ([[no-email-in-repos]]). Launcher → ethan-owned `~/.local/bin` COPY deployed by install.sh ([[user-specific-via-my-system]], [[no-symlink-repo-to-home]]); it sources the file and hops to dev with `--preserve-env` for exactly the needed vars. Never place secrets on a command line (no `ps` exposure) and never pass them as CLI args to sub-tools — use the environment. Preflight should fail fast naming any missing secret, so a misconfiguration is a safe failure, not a silent leak.
