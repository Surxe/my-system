---
name: steam-tracker-venv
description: steam-price-tracker repo uses .venv; run python/pytest via .venv/bin/python
metadata: 
  node_type: memory
  type: project
  originSessionId: 605f785f-e850-49fa-988b-e3c66c0161f6
  modified: 2026-08-04T23:21:31.413Z
---

The `/srv/dev/repos/steam-price-tracker` repo has a project virtualenv at `.venv/` (gitignored). pytest is installed only there (system Python blocks pip via PEP 668).

**How to apply:** Run the app and tests through the venv — `.venv/bin/python -m pytest`, `.venv/bin/python -m steam_price_tracker`. Don't use `/usr/bin/python` for this repo; it lacks pytest. Dev deps live in `requirements-dev.txt`. See [[repos-location]].
