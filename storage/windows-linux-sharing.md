# Windows ↔ Linux sharing

The machine dual-boots Windows and Debian, sharing the OS drive
([disk-layout.md](disk-layout.md)). A single shared directory bridges the two:

```
Windows:  C:\os-shared
Linux:    /mnt/os-shared
```

Purpose: shared data between Windows and Linux (documents, transfer scratch,
cross-OS assets).

## Access policy

- The shared directory should be accessible by both **`ethan`** and **`dev`**.
- **Linux does not need general access to the Windows `C:` drive** — expose only
  `os-shared` under normal operation.
