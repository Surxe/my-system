---
name: clip-tagging-mcp
description: "Gaming-clip tagging + query MCP project — architecture, stack decisions, and where it runs"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8e05f607-42e3-486d-bdc5-b218912b4e75
  modified: 2026-08-06T05:06:57.172Z
---

Building a system to tag gaming clips (controlled-vocab `tags.json`, LLM maps a short free-text description onto the vocab — no fuzzy matching, no frame/audio AI) and query them via a **local stdio MCP**. Brief: `/srv/dev/scratch/clip-tagging-mcp-brief.md`. Started 2026-08-04.

**Architecture (from brief):** shared `clip_core` (schema, tags vocab, `llm_classify`, `query`, media I/O) with two entry points — `ingest.py` (batch tagging script, deterministic, plain Anthropic API calls) and `clips_mcp.py` (query + retrieval MCP). Tagging = script; querying = MCP. One asset = split-audio **master** (source of truth) + regenerable `_merged.mp4`; tag once on the master, linked by filename stem. Tags stored in a rebuildable SQLite index (optionally ExifTool-embedded in masters).

**Stack decisions (researched 2026-08-04):**
- MCP framework: use the **official `mcp` Python SDK's bundled server** (`pip install "mcp[cli]"`; class renamed FastMCP→`MCPServer` in SDK v2.0 beta). NOT standalone `PrefectHQ/fastmcp` 3.x — that's diverged, heavier, aimed at hosted/OAuth setups we don't want. Standalone is the upgrade path only if we ever need OAuth/shared-server.
- LLM classifier: Anthropic Claude (no other provider in the repos). Single constrained-classification call with structured outputs (json_schema `enum` of tags.json + optional propose-new-tag field). Default `claude-opus-5`; benchmark `claude-haiku-4-5` for cheap batch. See [[[claude-api]]] skill.
- Tag storage: ExifTool writes top-level QuickTime+XMP keyword tags to MP4 fine (the MP4 limitation is only track-specific/timed metadata, which we don't touch). SQLite via stdlib `sqlite3`.

**Where it runs (decided 2026-08-04):** the **Linux dev box** (`/srv/dev`), not Windows. MCP client is Claude Code here, not Claude Desktop.

**Ingest pipeline / clip flow (corrected 2026-08-04):** User now records on **both Windows and Linux**. The 4 old scripts (2 .bat, 2 .py in /srv/dev) are legacy from the Windows-only system — **ignore them as design basis; new scripts not yet written.**
- Staging: clips land in `os-shared/transfer/clips/*` = **`/mnt/os-shared/transfer/clips/*`** on Linux (an NTFS3 mount of the shared Windows C partition `/dev/nvme1n1p3`; Windows sees same folder). Clips live there **temporarily**.
- Windows→os-shared move: **user's own script** (their responsibility, not ours).
- Linux side (OURS): a step moves clips from `/mnt/os-shared/transfer/clips/*` → the **generic intake** that runs the dev pipeline (tag + categorize via ingest.py) → permanent categorized library.
- Our systems can **depend on** clips temporarily living at `/mnt/os-shared/transfer/clips/*`.
- Merge/short scripts, when rebuilt: ffmpeg parts port to Linux; drop the Windows-only `win32clipboard` Discord-clipboard bit.

**OPEN:** permanent Linux library + SQLite index location (NTFS staging is temporary — masters as source-of-truth should land on ext4, e.g. under /srv/dev). And whether the intake move is manual, a watcher, or invoked by ingest.py.

**Tooling on Linux box:** ffmpeg/ffprobe/mediainfo ✅, Python 3.13 ✅, stdlib sqlite3 ✅. `exiftool` still missing (embed_tags is a guarded no-op until installed).

**SCAFFOLDED 2026-08-04:** repo `/srv/dev/repos/clip-db` (git init + initial commit `17cf4bd`, no remote yet — user will make public on GH). Monorepo: shared `clip_core/` (config, tags, schema, index, media, classify, query) + `clip-tagger/ingest.py` + `clip-viewer-mcp/server.py` + `tests/` (20 pytest tests, all green). Paths via `.env` (`.env.example` committed; real `.env` gitignored — user still needs to create it). Hyphenated project dirs aren't importable, so entry scripts do a `sys.path` insert of repo root; `pytest.ini` sets `pythonpath = .`. Run via **`.venv/bin/python` / `.venv/bin/pytest`** (venv built from requirements-dev.txt).
- **Gotcha resolved:** `mcp` SDK is now **2.0.0** — `mcp.server.fastmcp` is GONE; use `from mcp.server import MCPServer` (drop-in for old FastMCP: same `.tool()` / `.run()`). Pinned `mcp[cli]>=2,<3` in requirements.
- Classifier uses Anthropic `messages.create` with `output_config.format` json_schema (tags = enum of vocab + nullable proposed_tag); `llm_classify` takes an injectable `client` for tests. See [[claude-api]].
- **Tag vocab restructured (commit `ceffb83`):** `tags.json` is two-tier — `generic` (cross-game) + `games` keyed by display name. **Game name is a tag; every item is a tag; group labels are NOT tags** (organisation/readability only). `TagVocab` (clip_core/tags.py) carries a flat normalized enum (single source for schema+membership) AND the grouped structure; `to_markdown()` renders the grouped view which classify.py feeds the model (enum still constrains exact output). Loader still accepts legacy `{"tags":[...]}`/bare list. Seeded **War Robots Frontiers** (weapons 51 / modules 65 / abilities 82 + game name; `Mk. I`/`Mk. II` excluded; 180 tags after cross-group dedupe + 6 generic). Regenerate WRF from the `WRFrontiersDB-Data` repo (`current/Objects/Module.json` Ready-only split by `module_type_ref` "Weapon"→weapons else modules; `Ability.json` all) via `scripts/extract_wrf_tags.py` (reproduces file exactly). Model + how-to-add-a-game documented in `docs/tags.md`. Tests now 23.
- **Still stubbed / follow-ups:** per-clip description input (currently one `--description` for all masters — needs sidecar/manifest/interactive); query parser is left-to-right AND/OR, no parens; `regenerate_merged`/`embed_tags`/`probe_duration` not unit-tested (need ffmpeg/exiftool/real media). Backup-to-flashdrive tie-in deferred (user's call, don't research).
