# Disk layout

Physical devices are described in [../hardware/storage.md](../hardware/storage.md).

## NVMe 0 — Samsung 970 EVO Plus (OS drive, shared)

Partitions:

```
EFI          # shared EFI system partition
Windows      # Windows install
Debian root  # → mounted at /  (ext4)
```

## NVMe 1 — Samsung 980 Pro

```
/home        # ext4
```

Mount table: [mounts.md](mounts.md). The `os-shared` cross-OS directory lives on
the Windows partition — see [windows-linux-sharing.md](windows-linux-sharing.md).
