# Development directory layout

All development lives under `/srv/dev`, shared via the `developers` group with
setgid inheritance ([../users-and-permissions/filesystem-permissions.md](../users-and-permissions/filesystem-permissions.md)).

```
/srv/dev/
├── repos/     # git repositories  (this repo lives here)
├── scratch/   # temporary experiments
├── tools/     # local tooling
└── docs/      # local documentation
```

- **Git repositories** → `/srv/dev/repos`.
- **Temporary experiments** → `/srv/dev/scratch`.
- AI assistants should operate primarily within `/srv/dev/repos` and
  `/srv/dev/scratch` ([claude.md](claude.md)).
