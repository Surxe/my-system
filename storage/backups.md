# Backups

Backups are **selective / document-level**, not full-system imaging.

Tool: **Restic** → **Backblaze B2** — see [restic.md](restic.md).

## Scope

**Backed up:**

- important documents
- tax documents
- keys
- configuration files

**Not backed up:**

- full system image (not intended)

A read-only health check is available at
[../scripts/backup-check.sh](../scripts/backup-check.sh).
