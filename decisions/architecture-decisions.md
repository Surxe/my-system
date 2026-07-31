# Architecture decisions

Deliberate, settled choices. When one changes, update the relevant domain file
**and** amend this log. Options considered and rejected are in
[rejected-options.md](rejected-options.md); planned work is in
[future-plans.md](future-plans.md).

| Decision | Rationale / notes |
| --- | --- |
| Dual-boot Windows + **Debian 13 Trixie** | Debian as daily driver; Windows retained |
| **KDE Plasma** desktop | — |
| **Wayland** display server | Intentional; NVIDIA-compatible ([../operating-system/wayland.md](../operating-system/wayland.md)) |
| **ext4** for root and home | Simplicity, maintainability over btrfs/zfs |
| **Proprietary NVIDIA** driver | RTX 5070 support; Secure Boot disabled to avoid signing |
| **Secure Boot disabled** | Supports unsigned NVIDIA modules |
| `ethan` / `dev` / `developers` model | Shared dev access under `/srv/dev` with setgid |
| `/srv/dev` workspace | repos / scratch / tools / docs |
| **Restic → Backblaze B2** backups | Selective document-level, not full image |
| **Steam + Proton GE** for gaming | GE-Proton11-3 |
