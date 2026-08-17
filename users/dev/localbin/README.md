# dev's `localbin/` — PATH executables

Deployed by `../../install.sh` (`installers/dev-bin.sh`, step `dev-bin`) into
`~dev/.local/bin/` as a **copy**, mode `0755`. These are dev's *own* files — dev
already controls its home — so there is **no review gate** (same trust model as
dev's `.bashrc.d/`, `CLAUDE.md`, and skills). `~/.local/bin` is on dev's PATH via
Debian's stock `~/.profile` (the same dir `todo` lands in via `todo-dev`).

| File | Does |
| --- | --- |
| `new` | Start a **fresh** Claude Code session in place, without inheriting the current session's `/rename` name that `/clear` would carry over (todo t-0053). Run it inside Claude as `!new`, then exit (Ctrl+D) to cycle. |

## How `new` works

`/clear` keeps a `--name`/`/rename` name by design and only drops an AI-generated
title, so cleared sessions collide by name in `/resume`. A genuinely fresh
identity needs a new `claude` process. A command run inside Claude (via `!`) is a
child of `claude` and can't relaunch its parent, so `new` uses a handshake with
the `cc` launcher:

1. `cc` (see `../.bashrc.d/10-claude.sh`) runs Claude in a `while` loop and
   exports `CLAUDE_NEW_SENTINEL=<per-launch file path>`.
2. `!new` writes that file and prints a reminder to exit.
3. You press Ctrl+D (or `/exit`); the loop sees the file and relaunches a
   brand-new session (new id + fresh AI title). A normal exit leaves the file
   absent, so the loop breaks and returns to the shell as before.
