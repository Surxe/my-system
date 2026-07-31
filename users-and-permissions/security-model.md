# Security model

High-level boundaries for this machine. AI-assistant operating rules are the
canonical source: [../CLAUDE.md](../CLAUDE.md).

## Principles

- **Least privilege for `dev`** — an automation account, not a general
  interactive login ([users.md](users.md)).
- **Explain before changing** system config, permissions, or installing unusual
  packages. Prefer Debian-native, explicit, understandable configuration.
- **Secrets never live in this repo.** SSH private keys, passwords, API tokens,
  and backup credentials are off-limits — see
  [../private/secrets-policy.md](../private/secrets-policy.md).
- **Secure Boot is disabled intentionally** ([../operating-system/boot.md](../operating-system/boot.md)).

## Backups

Selective document-level backups via Restic → Backblaze B2
([../storage/restic.md](../storage/restic.md)). Credentials are secrets.
