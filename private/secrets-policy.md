# Secrets policy

**No secrets are stored in this repository — ever.** This file documents *what*
counts as a secret and *where* such things live; it never contains the secrets
themselves.

## What is a secret (never commit)

- SSH private keys and passphrases
- passwords
- API tokens
- Restic repository password / Backblaze B2 credentials
- any other credential or key material

## Where they actually live

- On-disk, outside this repo, with restrictive permissions (e.g. `~/.ssh/`,
  password-file paths referenced only by environment variables).
- Provided to tooling via the **environment**, not files in the repo — see
  [../scripts/backup-check.sh](../scripts/backup-check.sh) and
  [../storage/restic.md](../storage/restic.md).

## Guards

- The repo [.gitignore](../.gitignore) blocks common secret patterns
  (`*.key`, `*.pem`, `*.env`, `credentials*`, `*.age`, `*.gpg`, and
  `private/encrypted-notes/`).
- AI assistants must **never** access secrets ([../CLAUDE.md](../CLAUDE.md),
  [../users-and-permissions/security-model.md](../users-and-permissions/security-model.md)).

## Encrypted notes

Any personal encrypted notes are kept out of the repo — see
[encrypted-notes.md](encrypted-notes.md).
