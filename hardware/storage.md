# Storage (physical drives)

Two NVMe SSDs. Partitioning and mounts are documented under
[../storage/](../storage/disk-layout.md) — this file covers the physical devices.

## NVMe 0 — Samsung 970 EVO Plus (OS drive)

Shared between Windows and Linux. Holds the EFI, Windows, and Debian-root
partitions. See [../storage/disk-layout.md](../storage/disk-layout.md).

## NVMe 1 — Samsung 980 Pro (Linux home)

Dedicated to Linux `/home`. See [../storage/mounts.md](../storage/mounts.md).
