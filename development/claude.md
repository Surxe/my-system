# Claude / AI usage

The canonical operating rules for AI assistants are in [../CLAUDE.md](../CLAUDE.md)
(auto-loaded in this repo). Summary:

- Operate primarily inside `/srv/dev/repos` and `/srv/dev/scratch`.
- Avoid unrestricted system modification. **Explain the impact first** before
  changing system config, permissions, or installing unusual packages.
- **Never** access SSH private keys, passwords, API tokens, backup credentials,
  or any other secrets ([../private/secrets-policy.md](../private/secrets-policy.md)).
- Prefer Debian-native, simple, explicit, maintainable solutions; preserve
  working architecture.
- Help write code and commits, but avoid automatic destructive actions; commit /
  push only when asked.

The `dev` account exists partly to host this tooling in an isolated way
([../users-and-permissions/users.md](../users-and-permissions/users.md)).
