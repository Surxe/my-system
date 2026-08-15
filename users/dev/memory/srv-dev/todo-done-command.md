---
name: todo-done-command
description: "Mark a todo done with `todo done <id>`; reopen/rm are the rest of the lifecycle"
metadata:
  node_type: memory
  type: reference
---

To mark a todo complete: **`todo done <id>`** (e.g. `todo done t-0045`). No research needed — this is the supported verb.

Lifecycle verbs (from `todo --help`):
- `todo done <id>` — mark complete
- `todo reopen <id>` — undo a done
- `todo rm <id>` — delete

Related, instant/no-model: `todo add <text…>` (capture raw), `todo list [--repo X|--type T|--all|--done]`, `todo show <id>` (prints JSON with `id`, `created`, `text`, `status`). Fresh captures have `"status": "raw"`; `classify` (dev only) drains the inbox through the classifier.

**How to apply:** When Ethan explicitly asks to mark/close a todo, run `todo done <id>` directly — do not re-derive the command. Acting still requires an explicit ask: [[todo-command-no-action]].
