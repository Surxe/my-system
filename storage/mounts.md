# Mounts

| Mount | Device | Filesystem | Access |
| --- | --- | --- | --- |
| `/` | Samsung 970 EVO Plus (Debian root partition) | ext4 | |
| `/home` | Samsung 980 Pro (NVMe 1) | ext4 | |
| `/mnt/.raw/windows-c` | Windows `C:` (raw) | ntfs3 | rw, gated behind `0700 root:root` `/mnt/.raw` (`dev` cannot reach) |
| `/mnt/.windows-c` | bind of `/mnt/.raw/windows-c` | ntfs3 | **read-only** for everyone |
| `/mnt/os-shared` | bind of `/mnt/.raw/windows-c/os-shared` | ntfs3 | rw for `ethan` + `dev` |

`dev` can modify Windows `C:` **only** through `/mnt/os-shared`; the rest of
`C:` is read-only (`/mnt/.windows-c`) or unreachable (`/mnt/.raw`). Mechanism and
reproduction notes: [windows-linux-sharing.md](windows-linux-sharing.md).

Partition detail: [disk-layout.md](disk-layout.md). Filesystem rationale (ext4):
[../operating-system/filesystem-layout.md](../operating-system/filesystem-layout.md).

> Verify live mounts with `scripts/inventory.sh` (`lsblk`, `mount`, `df -h`).
