---
name: tag-clip
description: >-
  Add a tag to a gaming clip through the clip-viewer MCP the right way: canonicalize
  it against the controlled vocabulary, register anything new, and expand implications
  before writing. Use whenever you are about to call the clip-viewer `add_tag` or
  `set_tags` tool, or the user asks to tag a clip. Keeps the clip index and the
  clip-db vocabulary (tags.json / tag_aliases.json / tag_implications.json) in sync.
---

# Tag a clip (vocabulary-aware)

The clip-viewer MCP tools `add_tag` / `set_tags` write **straight to the clip SQLite
index**. They do **not** consult the controlled vocabulary and do **not** apply aliases
or implications — so a mistyped or brand-new tag sticks silently and off-vocabulary.
This skill makes you bridge the two stores every time you tag a clip.

The vocabulary lives in the **clip-db** repo (`/srv/dev/repos/clip-db`), which is
dev-writable:

- `tags.json` — the controlled vocabulary: a `generic` list plus `games/<game>/groups/<group>` lists.
- `tag_aliases.json` — community nicknames that resolve **to** a canonical vocab tag (a nickname is never itself a tag).
- `tag_implications.json` — a tag **expands** to imply others (e.g. every player implies `notable-player`).

Run all Python via the repo venv: **`/srv/dev/repos/clip-db/.venv/bin/python`**.

## When this fires

Any time you are about to add or set tags on a clip via `mcp__clip-viewer__add_tag` or
`mcp__clip-viewer__set_tags`, or the user says "tag this clip …". Run the procedure
below for **each** tag before writing it.

## Procedure — per tag, before any MCP write

### 1. Load vocabulary + relations

Read the three files through `clip_core` so there is one source of truth (never re-parse
by hand):

```
cd /srv/dev/repos/clip-db && .venv/bin/python -c "
from clip_core import vocab_edit as v
from clip_core.relations import TagRelations
tags = v.load_tags()
rel = TagRelations.load(aliases_path=v.ALIASES_JSON, implications_path=v.IMPLICATIONS_JSON)
print('resolve:', rel.resolve(['<the raw tag>']))
"
```

### 2. Canonicalize via aliases

If the raw tag is a known alias (e.g. `incin` → `Incinerator`, `pocket` → `captain caveman`,
`tp` → `Translocator`), replace it with its canonical vocab tag. `rel.resolve([tag])` does
this for you — the first element back is the canonical form. **Never** register an alias
as a new vocab entry.

### 3. Vocabulary membership check

Check the canonical tag against `tags.json` — case-insensitively, across `generic` **and**
every `games/<game>/groups/<group>` list. If it is already present, use the canonical
casing from the file and go to step 5.

### 4. If the tag is new — register it (human-in-the-loop)

Do **not** silently invent a group. Instead:

- **Infer the game** from the clip (its `game` field, or a game tag like `war robots frontiers`).
- **List the game's actual groups in chat**, read live from `tags.json` — do not hardcode
  them (they change). For example:

  ```
  cd /srv/dev/repos/clip-db && .venv/bin/python -c "
  from clip_core import vocab_edit as v
  g = v.load_tags()['games'].get('War Robots Frontiers', {}).get('groups', {})
  print('groups:', sorted(g))
  "
  ```

- **Suggest** the most likely group, then **ask the user to confirm or pick** one of the
  listed groups (or `generic` for a cross-game tag). Player handles are the one case you
  may route automatically → the `players` group.
- **Register** with the single-source-of-truth CLI (idempotent, case-insensitive dedupe,
  comma-guarded, keeps game groups sorted):

  ```
  cd /srv/dev/repos/clip-db && .venv/bin/python scripts/add_tags.py \
    --game "<Game>" --group <group> "<tag>"
  # cross-game instead:
  # .venv/bin/python scripts/add_tags.py --generic "<tag>"
  ```

- **If you filed it under `players`**, also seed the implication so the behavior is
  dynamic — a player implies `notable-player` exactly like every other player, not as a
  hardcoded special case:

  ```
  cd /srv/dev/repos/clip-db && .venv/bin/python scripts/add_tags.py \
    --game "<Game>" --implies "<player>" notable-player
  ```

- **Aliases** work the same way when the user tells you a nickname should map to a
  canonical tag (`--alias CANONICAL NICK [NICK ...]`, writes `tag_aliases.json`). Only add
  an alias when the user asks — do not invent nicknames.

### 5. Expand implications, then write

Re-run `rel.resolve([canonical_tag])` (reload relations if you just seeded one) to get the
full expanded set — the tag plus everything it implies. Then write **each** resolved tag to
the clip with `mcp__clip-viewer__add_tag`. So adding `sir tubins` also lands `notable-player`
automatically, driven by the implication file rather than a hardcoded rule.

> Note: the classifier normally applies `resolve()` only at classify time (existing clips
> are never rewritten). This skill deliberately applies it at manual-tag time too — that
> is the intended behavior here.

### 6. Close out — offer a PR, never auto-commit

If you changed `tags.json`, `tag_aliases.json`, or `tag_implications.json`, they are now
**uncommitted** in the dev-writable clip-db repo. Tell the user what changed and **offer**
to open a PR (via the `pr` skill). Do not commit or push unless asked.

## Guardrails

- **Two stores, one truth.** The MCP index and the vocabulary are separate; a tag must be
  valid in the vocabulary before it lands on a clip.
- **Never register an alias as a vocab tag** — aliases resolve to a canonical tag, they are
  not tags themselves.
- **Only `ability_implies` is hand-editable.** `--implies` writes there; the
  `ability_to_module` block is generated from game data — never hand-edit it.
- **Ask before inventing a group.** Player handles auto-route to `players`; everything else
  is suggested-then-confirmed against the live group list.
- **No commas in tags** (the index delimiter) — the CLI rejects them; so should you.
