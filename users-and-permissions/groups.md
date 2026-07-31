# Groups

## `developers`

Shared access between:

- `ethan`
- `dev`
- development tooling

Used to share everything under `/srv/dev`. The permission convention that makes
this work (setgid inheritance) is in
[filesystem-permissions.md](filesystem-permissions.md).

> Confirm membership with `getent group developers` (run by `scripts/inventory.sh`).
