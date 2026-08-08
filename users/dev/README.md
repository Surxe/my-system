# dev-user

Generates the `CLAUDE.md` used by the **dev** user, assembled from a template
plus auto-generated sections.

## How it works

```
CLAUDE.md.blueprint ──┐
                      ├─► build-claude-md.sh ─► CLAUDE.md ─(symlink)─► ~/.claude/CLAUDE.md
sections/*.md ────────┘        ▲
      ▲                        │
      └── scripts/generate-*.sh (run in phase 1)
```

- **`CLAUDE.md.blueprint`** — the template. Holds the fixed structure/prose and
  a whole-line `{{token}}` for each section to embed. Edit this for layout.
- **`scripts/generate-*.sh`** — one generator per section; each writes
  `sections/<name>.md`. Currently just `generate-repo-descriptions.sh`, which
  lists every repo under `/srv/dev/repos` with its GitHub *description* (repo
  metadata fetched from the API — public repos need no auth, private repos use
  dev's PAT read from the git credential helper at runtime; never hardcoded).
- **`build-claude-md.sh`** — the master. (1) runs every registered generator to
  refresh `sections/`, then (2) expands each `{{token}}` in the blueprint with
  the matching `sections/<name>.md` and writes `CLAUDE.md` atomically.

## Usage

```bash
./build-claude-md.sh        # regenerate sections + rebuild CLAUDE.md
```

Never edit `CLAUDE.md` or `sections/*.md` by hand — they are generated. Edit the
blueprint or the generators instead.

## Wiring to dev's global config

```bash
ln -s /srv/dev/repos/my-system/users/dev/CLAUDE.md ~/.claude/CLAUDE.md
```

## Adding a new section

1. Write `scripts/generate-<name>.sh` that emits `sections/<name>.md`.
2. Register it in `SECTION_GENERATORS` in `build-claude-md.sh`.
3. Add `{{<name>}}` on its own line in `CLAUDE.md.blueprint` where it should appear.
