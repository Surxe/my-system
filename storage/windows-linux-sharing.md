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
- **`dev` must be unable to modify anything on Windows `C:` except `os-shared`.**

## Enforcement (mount layout)

Windows `C:` is one NTFS filesystem, so its write permissions (`uid`/`gid`/
`*mask`) are superblock-wide — you cannot make `os-shared` writable while the
rest of `C:` is not via ownership alone. Instead we control access **per mount
path** in `/etc/fstab`:

```
# raw device, rw, hidden behind a root-only gate dir (dev cannot traverse /mnt/.raw)
UUID=…  /mnt/.raw/windows-c   ntfs3  uid=1000,gid=1001,dmask=0002,fmask=0002,umask=0002,nofail  0 0
# public view of C: — read-only for everyone (per-mount ro bind)
/mnt/.raw/windows-c            /mnt/.windows-c  none  bind,ro,nofail,x-systemd.requires=/mnt/.raw/windows-c  0 0
# shared exchange folder — writable (dev writes via the developers group)
/mnt/.raw/windows-c/os-shared  /mnt/os-shared   none  bind,nofail,x-systemd.requires=/mnt/.raw/windows-c  0 0
```

Why each piece matters:

- The NTFS superblock must be mounted **rw somewhere** so the `os-shared` bind
  can be writable — that raw mount lives at `/mnt/.raw/windows-c`.
- `/mnt/.raw` is `0700 root:root`. `dev` lacks execute (traverse) on it, so path
  resolution to the group-writable raw tree fails with `EACCES` before NTFS
  perms are ever checked — knowing the path doesn't help, and `dev` has no
  sudo/capabilities to bypass it.
- `/mnt/.windows-c` is a **read-only bind** (`MNT_READONLY`, per-mount) — writes
  are denied regardless of the rw superblock underneath, for `ethan` too.
- `/mnt/os-shared` is a plain rw bind of just the `os-shared` subdir; `dev`
  writes via the `developers` group. Bind mounts can't escape upward
  (`/mnt/os-shared/..` is `/mnt`, not the `C:` root).
- Binds use `x-systemd.requires=/mnt/.raw/windows-c` so systemd mounts the raw
  NTFS **before** them at every boot. (Do not put `x-systemd.automount` on the
  raw line — the binds would then land on the empty mountpoint dir instead of
  the filesystem.)

Verify as `dev`: write to `/mnt/.windows-c` → `Read-only file system`; `ls
/mnt/.raw` → `Permission denied`; write to `/mnt/os-shared` → succeeds.

### Reproducing on another machine

Machine-specific values to adjust before applying the fstab block above:

- **`UUID=…`** — the Windows `C:` NTFS partition UUID on this box is
  `06A2FAE3A2FAD5E1`. Find the target machine's with `blkid` /
  `lsblk -o NAME,UUID,FSTYPE`.
- **`uid=1000,gid=1001`** — `1000` = `ethan` (owner), `1001` = the `developers`
  group that `dev` belongs to. Match these to the target machine's actual
  `ethan` uid and `developers` gid (`id ethan`, `getent group developers`); the
  writable-via-group behavior depends on `dev` being in that group.
- The masks (`dmask=0002,fmask=0002,umask=0002`) give the `developers` group
  write while keeping "others" read-only — keep as-is.

Setup order on a fresh machine: create `/mnt/.raw` (`0700 root:root`),
`/mnt/.raw/windows-c`, `/mnt/.windows-c`, `/mnt/os-shared`; add the three fstab
lines; `systemctl daemon-reload`; then `mount /mnt/.raw/windows-c` before the
two binds. The `os-shared` subdir must already exist inside Windows `C:`.
