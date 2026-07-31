# Filesystem layout

**Filesystem: ext4** on both root and home (chosen for simplicity and
maintainability over btrfs/zfs).

## Mounts

| Mount | Device | FS |
| --- | --- | --- |
| `/` | Samsung 970 EVO Plus (Debian root partition) | ext4 |
| `/home` | Samsung 980 Pro (NVMe 1) | ext4 |
| `/mnt/os-shared` | Windows `C:\os-shared` | — |

Full mount + partition detail: [../storage/mounts.md](../storage/mounts.md),
[../storage/disk-layout.md](../storage/disk-layout.md).

## Development workspace

Development lives under `/srv/dev` — see
[../development/directory-layout.md](../development/directory-layout.md).
