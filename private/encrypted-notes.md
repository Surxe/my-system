# Encrypted notes

**Placeholder / pointer only — this file holds no sensitive content.**

Actual encrypted notes are **not** stored in this repository. If encrypted notes
are ever kept alongside this repo, they must be:

- encrypted at rest (e.g. `age` or `gpg`), and
- excluded from git — the [.gitignore](../.gitignore) already ignores
  `private/encrypted-notes/`, `*.age`, and `*.gpg`.

Never commit plaintext secrets here. See [secrets-policy.md](secrets-policy.md).
