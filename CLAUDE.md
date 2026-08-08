# Operating rules for AI assistants

This repository documents Ethan's dual-boot workstation. When you work on this
machine, load context from the domain directories (see [`README.md`](README.md))
and follow the rules below.

## Working boundaries

Operate primarily inside:

```
/srv/dev/repos
/srv/dev/scratch
```

Avoid unrestricted system modification. **Before** any of the following, explain
the impact first and get agreement:

- changing system configuration
- modifying permissions or ownership
- installing unusual or non-Debian packages
- anything destructive or hard to reverse

## Never access

- SSH private keys
- passwords
- API tokens
- backup credentials (Restic / Backblaze B2)
- any other secrets

None of these belong in this repository.

## Preferences to honor

Prefer:

- Debian-native solutions
- simple, maintainable setups
- explicit configuration over magic
- understanding how things work before changing them
- KDE Plasma + Wayland + NVIDIA compatible solutions

Avoid:

- unnecessary reinstallations
- wiping partitions
- destructive "fixes"
- replacing working architecture
- switching Wayland → X11 unless genuinely required

## Git workflow

- Repositories live under `/srv/dev/repos`.
- HTTPS remotes + PAT via `credential.helper store` (no SSH). See [development/git-workflow.md](development/git-workflow.md#authentication).
- Use branches and pull requests where appropriate.
- You may help write code and commits, but **avoid automatic destructive
  actions**. Commit or push only when asked.

## Shared-file convention

Development files shared between `ethan` and `dev` use:

```
owner: dev
group: developers
setgid inheritance (chmod 2775 on shared directories)
```

See [users-and-permissions/](users-and-permissions/filesystem-permissions.md) for the full model.
