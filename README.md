# System Context

Persistent, human- and AI-readable context for Ethan's dual-boot workstation
(Windows + Debian 13 Trixie).

## Purpose

This repository is the **single source of truth** for how this machine is set up:
hardware, OS decisions, filesystem layout, the user/group model, development
workflow, security boundaries, gaming setup, and the history behind those
choices.

The goal is to avoid repeatedly rediscovering the same facts across sessions and
tools. When making recommendations, **prefer preserving existing decisions**
unless there is a strong, stated reason to change them.

This is documentation only — it contains no secrets, credentials, or keys, and
none should ever be committed here. See [private/secrets-policy.md](private/secrets-policy.md).

## How to use it

- **Humans:** browse by domain directory below.
- **AI assistants:** start with [`CLAUDE.md`](CLAUDE.md) for operating rules and
  boundaries, then load the specific file(s) you need.

## Layout

One directory per domain, one file per component:

- **[hardware/](hardware/overview.md)** — CPU, GPU, motherboard, memory, storage, peripherals
- **[operating-system/](operating-system/debian.md)** — Debian, desktop, Wayland, filesystem layout, boot, kernel
- **[users-and-permissions/](users-and-permissions/users.md)** — users, groups, sudo, filesystem permissions, security model
- **[development/](development/overview.md)** — directory layout, languages, editors, git, ssh, Claude
- **[storage/](storage/disk-layout.md)** — disk layout, mounts, Windows↔Linux sharing, backups, restic
- **[gaming/](gaming/overview.md)** — Steam, Proton, NVIDIA, MangoHud, GameMode, Heroic, compatibility
- **[applications/](applications/installed.md)** — installed apps, browsers, editors, media tools, utilities
- **[services/](services/systemd.md)** — systemd, Docker, containers
- **[decisions/](decisions/architecture-decisions.md)** — architecture decisions, rejected options, future plans
- **[troubleshooting/](troubleshooting/known-issues.md)** — known issues, solved issues, commands
- **[scripts/](scripts/README.md)** — read-only inventory & backup-check helpers
- **[private/](private/secrets-policy.md)** — secrets policy (pointers only, never the secrets)

## Conventions

- Files marked **`TODO — not yet documented`** are scaffolds awaiting real
  content. Run [`scripts/inventory.sh`](scripts/inventory.sh) to gather much of it.
- Overlapping facts live in one canonical file and are **cross-linked** from the
  others (e.g. physical drives in [hardware/storage.md](hardware/storage.md),
  partitions in [storage/disk-layout.md](storage/disk-layout.md)).

## Keeping it current

Treat drift as a bug. When a decision changes or a component is added:

1. Update the relevant domain file.
2. If it was a deliberate choice, record it in
   [decisions/architecture-decisions.md](decisions/architecture-decisions.md).
3. Commit with a short message describing what changed and why.
