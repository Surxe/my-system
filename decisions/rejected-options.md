# Rejected / avoided options

Choices deliberately **not** taken, so they aren't re-proposed without reason.

| Rejected | Instead | Why |
| --- | --- | --- |
| X11 display server | Wayland | Wayland is intentional; X11 only as last-resort fallback |
| Re-enabling Secure Boot | Keep it disabled | Avoids NVIDIA module-signing overhead |
| Full system-image backups | Selective Restic backups | Only documents/keys/config are in scope |
| General Linux access to Windows `C:` | Expose only `os-shared` | Least exposure between OSes |
| btrfs / zfs | ext4 | Simplicity and maintainability |

See [architecture-decisions.md](architecture-decisions.md) for the accepted side
of each.
