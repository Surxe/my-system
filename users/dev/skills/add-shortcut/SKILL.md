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
- **Copy, don't reference, anything ethan EXECUTES (security invariant).** The
  leaf that runs as ethan must be a root-owned system binary (`/usr/bin/…`) or a
  **copy** in ethan's `~/.local/bin` — never a `/srv/dev/repos` path, which is
  dev-writable and would let a dev-tree edit run as ethan with no review gate.
  - Executables you author for a shortcut go in `users/ethan/localbin/`;
    `install.sh` copies them (review-gated) to `~/.local/bin`, and you reference
    the **deployed** path `/home/ethan/.local/bin/<name>` in `Exec`.
  - The helper **refuses** a `--command` that would exec a `/srv/dev/repos` path
    (directly or via `konsole -e …`); relocate the target into `localbin/` first.
  - `Path=` (cwd) and `Icon=` (asset SVGs) may stay in-repo — they are data, not
    code executed as ethan.
- **What reaches ethan's home:** the `.desktop` (to the menu + desktop) and any
  generated `.run.sh` runner (to `~/.local/bin`) — both as copies via `install.sh`.
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
- **Local executables must be copied, not referenced.** If the shortcut runs a
  script you control, place it in `users/ethan/localbin/<name>` and pass
  `--command /home/ethan/.local/bin/<name>`. The helper refuses a `--command`
  that execs a `/srv/dev/repos` path (see the security invariant above); the only
  bypass is `--allow-repo-exec`, reserved for documented exceptions (e.g. a
  cross-repo runner, or the deploy-my-system-config bootstrap).
- For a **terminal** command, the helper also generates a `<slug>.run.sh` runner
  that runs the command then pauses (*"Press any key to close…"*) so output and
  errors stay readable, and points `Exec=` at it. The runner is written to
  `users/ethan/localbin/` (not `desktop-entries/`) because it too executes as
  ethan — so it is deployed as a copy into `~/.local/bin`.
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
`users/ethan/desktop-entries/<slug>.desktop` (and, if generated, the runner at
`users/ethan/localbin/<slug>.run.sh`, plus any executable you added to
`localbin/`). Commit only when the user asks, per the repo's git rules.

## Constraints

- Do not write into `~ethan` or run `install.sh` yourself (you're `dev`; it
  refuses for non-ethan and the deploy is ethan's to run and review).
- The `Exec` leaf must be a system binary or a `~/.local/bin` copy — never a
  `/srv/dev/repos` path (the helper enforces this). `Icon`/`Path` may be absolute
  in-repo paths (assets/cwd are data). Keep all paths absolute so ethan's KDE can
  reach them.
- Never embed secrets in a command or launcher (see `CLAUDE.md` "Never access").
