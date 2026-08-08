# SSH

- **SSH is intentionally not used for git.** All git remotes are HTTPS
  (`https://github.com/<owner>/<repo>.git`) and authenticate via
  `credential.helper store` — one classic PAT per identity (ethan = `Surxe`,
  dev = `Surxe-dev`). See [git-workflow.md](git-workflow.md#authentication).
- Both identities use the same method, differing only in credential store, so
  there is no SSH key material to manage for git.

> **Never** record private keys, passphrases, or key material here — those are
> secrets ([../private/secrets-policy.md](../private/secrets-policy.md)).
