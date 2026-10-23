# Filesystem permissions

## Shared-development convention

Shared development files under `/srv/dev` use:

```
owner: dev
group: developers (dev's primary group)
setgid inheritance
```

Two mechanisms put shared files in `developers`, and both are needed:

- **dev's primary group is `developers`** (there is no `dev` group). Everything
  `dev` creates is `developers`-owned by default, wherever it is created, so
  files written elsewhere and moved in (a scratchpad, a tool's temp dir, a cache)
  stay writable by `ethan`.
- **setgid on shared directories** covers files `ethan` creates, since his primary
  group is `ethan`.

Preferred pattern on shared development directories:

```bash
chmod 2775 <dir>   # rwx owner/group, r-x other, setgid bit
```

The setgid bit (`2###`) makes newly-created files inherit the `developers` group,
so both `ethan` and `dev` retain access to everything created under `/srv/dev`.
With `dev`'s umask of `0002` (set by `users/dev/.bashrc.d/05-umask.sh`, so it
applies to dev's interactive shells and anything launched from them), its files
are also group-writable.

Find files that escaped the convention with
`find /srv/dev ! -group developers -not -path '*/.git/*'`.

See [groups.md](groups.md) and
[../development/directory-layout.md](../development/directory-layout.md).
