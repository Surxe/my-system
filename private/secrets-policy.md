# Secrets policy

**No secrets are stored in this repository — ever.** This file documents *what*
counts as a secret and *where* such things live; it never contains the secrets
themselves.

## What is a secret (never commit)

- SSH private keys and passphrases
- passwords
- API tokens
- Restic repository password / Backblaze B2 credentials
- Gmail App Password for `steam-price-tracker` email alerts
- any other credential or key material

## Where they actually live

- On-disk, outside this repo, with restrictive permissions (e.g. `~/.ssh/`,
  password-file paths referenced only by environment variables). The
  `steam-price-tracker` SMTP App Password lives in `~ethan/.config/steam-price-tracker/smtp.env`
  (`chmod 600`, Ethan-owned), loaded into the tracker via the systemd unit's
  `EnvironmentFile`; the repo carries only `smtp.env.example`. That file is
  **hand-maintained by Ethan** (written/rotated by hand) — it is the source of
  truth; `install.sh` only bootstraps it via a one-time prompt if it is absent,
  and never overwrites it. Nothing else (no keyring, secrets manager, or restore
  step) populates it.
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
