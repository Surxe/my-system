---
name: add-to-taskbar
description: >-
  Add an app to one of Ethan's custom taskbars (the per-monitor "Launcher Group"
  widgets). Resolves the app to a launcher URL and inserts it into the declared
  config (users/ethan/kde-taskbar-groups.conf) via a helper, then hands the user
  the one command to deploy it (install.sh). Taskbars: hdmi1/hdmi2 (left monitor),
  dp2 (right monitor); dp1 is the stock default taskbar and is not managed here.
  Use whenever the user wants to add/pin an app to a taskbar, launcher group, or
  panel.
---

# Add an app to a taskbar

Add an app's launcher to one of the custom **Launcher Group** taskbar widgets by
editing the declared config, then hand off deployment to `install.sh`.

## Background — how these taskbars work

Each "taskbar" is a local Plasma plasmoid, `org.surxe.launchergroup` ("Launcher
Group"), that shows an app's launcher **only while the app is closed or
minimized** and hides it while the app has a visible window. Their shortcuts are
declared in `users/ethan/kde-taskbar-groups.conf` (per-monitor `[connector]`
sections, each with `group <Name>` blocks of launcher URLs). `install.sh`
asserts that conf onto the **already-existing** widgets — it never creates them.
Full design: `operating-system/taskbar-shortcut-groups.md`.

## The four taskbars → conf mapping

| Friendly name | Monitor | Conf location | Managed here? |
| --- | --- | --- | --- |
| `hdmi1` | left | `[HDMI-A-1]` group **coding** | yes |
| `hdmi2` | left | `[HDMI-A-1]` group **media** | yes |
| `dp2` | right | `[DP-2]` group **firefox** | yes |
| `dp1` | right | stock Icons-Only Task Manager (default) | **no** |

`dp1` is the stock default taskbar (the empty task manager that surfaces
minimized windows via the `show-minimized-tasks` directive). It is **not** a
Launcher Group and has no launcher list this flow manages — the helper refuses it
and points to the KDE GUI (right-click the app -> Pin) for pinning there.

## How this works here — read first

- **The live KDE session is ethan's; Claude runs as `dev` with no sudo and no
  write to `~ethan`.** You only edit this repo's conf (dev-writable). Launcher
  URLs are **data** the installer reads, not code executed as ethan, so there is
  no localbin/security dance (unlike `add-shortcut`).
- **This edits the `my-system` repo** — commit the changed conf when done.
- You do **not** run `install.sh` yourself — it's ethan's to run and review.

## Step 1 — Resolve the target taskbar and the app's launcher URL

**Taskbar:** the user names one of `hdmi1`, `hdmi2`, `dp2` (or describes it —
"left coding bar", "the media one", "firefox bar on the right"). Map it via the
table above. If they say `dp1` / "the default one", stop and explain it's the
stock task manager (pin via the GUI).

**App -> launcher URL:** produce an explicit `applications:<id>.desktop` URL.

- **Use an explicit `.desktop` id, never a `preferred://` alias.** The widget
  matches launchers to windows by the `.desktop` basename (lowercased); a
  `preferred://filemanager` alias never matches Dolphin's windows, so its
  hide-when-visible logic breaks. (The helper warns if you pass `preferred://`.)
- Find the id by searching the dev-readable app dirs:
  ```
  ls /usr/share/applications /var/lib/flatpak/exports/share/applications \
     /srv/dev/repos/my-system/users/ethan/desktop-entries 2>/dev/null | grep -i <app>
  ```
  Match the app to its `<id>.desktop` and build `applications:<id>.desktop`.
- Ethan's own apps under `~ethan/.local/share/applications` are **not**
  dev-readable — if you can't find the id there, confirm the exact
  `<id>.desktop` filename with the user rather than guessing.
- Flatpak exports can also be referenced as `file:///…​.desktop`; prefer the
  `applications:<id>.desktop` form when the id is on the standard search path.

## Step 2 — Insert with the helper

Run the helper (beside this file). It maps the friendly name to the conf
section/group, validates the URL, inserts it at the end of that group (idempotent
— a no-op if already present), and prints the updated group block:

```
/srv/dev/repos/my-system/users/dev/skills/add-to-taskbar/add-to-taskbar.sh \
  --taskbar <hdmi1|hdmi2|dp2> --launcher applications:<id>.desktop
```

It errors (non-zero) on `dp1`, an unknown taskbar name, a non-launcher-URL, or a
group/section missing from the conf. A missing group means the Launcher Group
widget doesn't exist yet — direct the user to
`operating-system/taskbar-shortcut-groups.md` ("Set up a new group") to add the
widget in the GUI first. Show the user the printed group block to confirm.

## Step 3 — Hand off deployment

Tell the user to run, in their own (ethan) session:

```
/srv/dev/repos/my-system/users/install.sh
```

The ethan-tier step matches each Launcher Group widget by its Group name and sets
its launchers from the conf (stopping/starting plasmashell so the change takes),
behind its review gate — the diff prompt is expected. The new launcher appears on
that taskbar while the app is closed or minimized.

## Step 4 — Commit

`my-system` is version-controlled. Commit the changed
`users/ethan/kde-taskbar-groups.conf`. Commit only when the user asks, per the
repo's git rules.

## Constraints

- Only `hdmi1`, `hdmi2`, `dp2` are managed; `dp1` is stock (GUI pin only).
- Prefer `applications:<id>.desktop`; never a `preferred://` alias.
- Don't write into `~ethan` or run `install.sh` yourself (you're `dev`).
- The helper never creates widgets — a missing group is a GUI setup step, not
  something this skill fabricates.
