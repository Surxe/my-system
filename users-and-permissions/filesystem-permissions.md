# Filesystem permissions

## Shared-development convention

Shared development files under `/srv/dev` use:

```
owner: dev
group: developers
setgid inheritance
```

Preferred pattern on shared development directories:

```bash
chmod 2775 <dir>   # rwx owner/group, r-x other, setgid bit
```

The setgid bit (`2###`) makes newly-created files inherit the `developers` group,
so both `ethan` and `dev` retain access to everything created under `/srv/dev`.

See [groups.md](groups.md) and
[../development/directory-layout.md](../development/directory-layout.md).
