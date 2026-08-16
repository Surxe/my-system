# dev/skills — Claude Code skills for the `dev` user

Version-controlled [Claude Code skills](https://docs.claude.com/en/docs/claude-code).
`users/install.sh` deploys this directory to `~dev/.claude/skills/` (dev-tier:
copied, no review gate — these are dev's own files), so each skill becomes
available in every `dev` Claude session as `/<skill-name>`.

```
skills/
  <skill-name>/
    SKILL.md        # frontmatter (name, description) + instructions
    *.sh            # optional helper scripts the skill calls
```

## Skills

- **add-shortcut** — create a KDE desktop/menu shortcut (`.desktop` launcher) for
  a given command. Generates the launcher into
  [`../../ethan/desktop-entries/`](../../ethan/desktop-entries/) via
  `add-shortcut/make-shortcut.sh`; `install.sh` deploys it to ethan's menu +
  desktop.
- **add-to-taskbar** — add an app to one of Ethan's custom "Launcher Group"
  taskbars (`hdmi1`/`hdmi2` on the left monitor, `dp2` on the right; `dp1` is the
  stock default and unmanaged). Resolves the app to a launcher URL and inserts it
  into [`../../ethan/kde-taskbar-groups.conf`](../../ethan/kde-taskbar-groups.conf)
  via `add-to-taskbar/add-to-taskbar.sh`; `install.sh` asserts it onto the live
  widgets. See `operating-system/taskbar-shortcut-groups.md`.
- **brainstorm** — divergent precursor to `/plan`. Given a feature idea, surfaces
  adjacent ideas, pros/cons, and open questions in one sharp pass, ending with a
  nudge to go deeper. Instructions-only (no helper script).

## Adding a skill

1. Create `skills/<name>/SKILL.md` (with `name:` / `description:` frontmatter).
2. Add any helper scripts alongside it; keep them `chmod +x`.
3. Run `users/install.sh` (as ethan) to deploy, or copy `skills/<name>/` into
   `~dev/.claude/skills/` for a quick local test.

Deploy is **additive** — removing a skill here does not delete it from
`~dev/.claude/skills/`; remove it there by hand if needed.
