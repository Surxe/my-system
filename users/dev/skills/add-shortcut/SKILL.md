---
name: add-shortcut
description: >-
  Create a KDE desktop/menu shortcut (a `.desktop` launcher) for a given command
  on this workstation. Generates the launcher into my-system's canonical
  desktop-entries dir via a helper script, then hands the user the one command to
  deploy it (install.sh). Use whenever the user wants a clickable shortcut,
  desktop icon, or app-launcher entry for a command, script, or app.
---

# Add a desktop shortcut

Generate a KDE `.desktop` launcher for a command and get it onto ethan's desktop
and app-launcher menu.

## How this works here — read first

- **The live KDE session is ethan's; Claude runs as `dev` with no sudo and no
  write access to `~ethan`.** So you never place files in ethan's home yourself.
  You author the launcher inside this repo (dev-writable); `users/install.sh`
  (run by ethan) copies it into ethan's menu + desktop behind its review gate.
- **Only the `.desktop` reaches ethan's home.** The `Exec`, `Icon`, and any
  generated runner stay in-repo and are referenced by absolute path — ethan can
  read/exec them via the shared `developers` group. Keep those paths absolute
  and under `/srv/dev/repos`.
- **Canonical location:** all launchers live in
  `/srv/dev/repos/my-system/users/ethan/desktop-entries/`. One dir for every
  shortcut, regardless of which repo the command belongs to (Option A).
- **This edits the `my-system` repo** — commit the new/changed files when done.

## Step 1 — Gather the command and infer the rest

The **command is the only required input**. Infer everything else, only asking
if genuinely ambiguous:

- **Name** — a readable title (helper derives one from the command if omitted).
- **Terminal vs GUI** — default **terminal** (`Terminal=true`). Choose `--gui`
  only when the target is clearly a windowed app that manages its own window
  (e.g. it launches a Qt/GTK GUI). A CLI script/tool is terminal.
- **Icon** — optional. Default is a themed name. If the command's repo ships an
  icon (e.g. an `assets/icon.svg`), pass its absolute path with `--icon`.
- **Working dir** — the helper infers `Path=` from an absolute command path;
  override with `--workdir` if the command should run from a repo root.

## Step 2 — Generate with the helper

Run the helper (it lives beside this file). It writes the launcher into the
canonical dir and validates it:

```
/srv/dev/repos/my-system/users/dev/skills/add-shortcut/make-shortcut.sh \
  --command '<cmd>' [--name '<Name>'] [--icon <name|abs-path>] \
  [--gui] [--no-wrap] [--workdir <dir>] [--comment '<text>']
```

Notes:
- For a **terminal** command, the helper also generates a `<slug>.run.sh` runner
  that runs the command then pauses (*"Press any key to close…"*) so output and
  errors stay readable, and points `Exec=` at it.
- Pass **`--no-wrap`** when the command already keeps its own terminal open
  (e.g. it ends with its own pause) — then `Exec=` points straight at it and no
  runner is generated.
- Run `make-shortcut.sh --help` for all flags.

Show the user the generated `.desktop` (read it back) so they can confirm.

## Step 3 — Hand off deployment

Deployment is **not** manual file copying — `install.sh` does it. Tell the user
to run, in their own (ethan) session:

```
/srv/dev/repos/my-system/users/install.sh
```

This regenerates artifacts, then (ethan-tier) copies every launcher in
`desktop-entries/` into **both** `~/.local/share/applications/` (menu) and
`~/Desktop/` (icon), refreshing the menu cache. The review gate will show a diff
and prompt for the new file — that's expected.

Then the **one** unavoidable GUI step: on first launch KDE asks to **trust** the
desktop icon — click *Trust*/*Allow* once. (The menu entry needs no trust.)

## Step 4 — Commit

`my-system` is version-controlled. Commit the new
`users/ethan/desktop-entries/<slug>.desktop` (and `<slug>.run.sh` if generated).
Commit only when the user asks, per the repo's git rules.

## Constraints

- Do not write into `~ethan` or run `install.sh` yourself (you're `dev`; it
  refuses for non-ethan and the deploy is ethan's to run and review).
- Keep `Exec`/`Icon` paths absolute and under `/srv/dev/repos` so ethan's KDE can
  reach them.
- Never embed secrets in a command or launcher (see `CLAUDE.md` "Never access").
