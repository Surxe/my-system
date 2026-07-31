# Mounts

| Mount | Device | Filesystem |
| --- | --- | --- |
| `/` | Samsung 970 EVO Plus (Debian root partition) | ext4 |
| `/home` | Samsung 980 Pro (NVMe 1) | ext4 |
| `/mnt/os-shared` | Windows `C:\os-shared` | see [windows-linux-sharing.md](windows-linux-sharing.md) |

Partition detail: [disk-layout.md](disk-layout.md). Filesystem rationale (ext4):
[../operating-system/filesystem-layout.md](../operating-system/filesystem-layout.md).

> Verify live mounts with `scripts/inventory.sh` (`lsblk`, `mount`, `df -h`).
