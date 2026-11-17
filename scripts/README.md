# Scripts

Small, **read-only** helpers for this context repo. None of them modify the
system or contain secrets.

| Script | Purpose |
| --- | --- |
| [inventory.sh](inventory.sh) | Print a read-only system snapshot to help populate the `TODO` scaffolds (hardware, kernel, mounts, packages, groups). |
| [backup-check.sh](backup-check.sh) | Read-only Restic health check. Reads credentials **from the environment** — never embeds them. |
| [find-orphaned-deploys.sh](find-orphaned-deploys.sh) | List deployed files (bashrc.d, local/bin, sbin, sudoers.d, udev) whose repo source is gone. `install.sh` never deletes, so these linger; candidates only. Run as ethan to cover ethan-tier. |

## Usage

```bash
# System snapshot (some sections need root for full detail, e.g. dmidecode):
scripts/inventory.sh
sudo scripts/inventory.sh          # fuller hardware detail

# Restic check — configure credentials in your environment first:
export RESTIC_REPOSITORY=...
export RESTIC_PASSWORD_FILE=/path/outside/this/repo
scripts/backup-check.sh
```

Credentials policy: [../private/secrets-policy.md](../private/secrets-policy.md).
