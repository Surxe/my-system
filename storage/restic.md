# Restic

| Aspect | Value |
| --- | --- |
| Backup tool | Restic |
| Cloud target | Backblaze B2 |

Scope of what's backed up: [backups.md](backups.md).

## Credentials — secrets

The Restic repository password and Backblaze B2 keys are **secrets**. They must
**never** be stored in this repository and AI assistants must not access them
([../private/secrets-policy.md](../private/secrets-policy.md)).

Provide them to tooling via the environment instead
(`RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE`, B2 credentials). The helper
[../scripts/backup-check.sh](../scripts/backup-check.sh) reads these from the
environment and never embeds them.
