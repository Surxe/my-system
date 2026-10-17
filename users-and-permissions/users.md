# Users

## `ethan` — primary user

- **UID:** `1000`
- The primary interactive user; daily driver for development, gaming, and general
  workstation use.

## `dev` — development user

- **UID:** `1001`; **primary group:** `developers` (no per-user `dev` group)
- Purpose: development automation, Claude tooling, isolated development workflows.
- **Not** a normal interactive account — don't treat it as one.

Both belong to the `developers` group ([groups.md](groups.md)) for shared access
to `/srv/dev`.
