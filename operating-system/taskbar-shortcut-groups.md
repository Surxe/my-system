# Taskbar shortcut groups (per-monitor "Launcher Group" widgets)

Grouped app shortcuts in each monitor's panel, where a shortcut is shown **only
when its app is not running, or running-and-minimized**, and hides while the app
has a visible window on any screen. This keeps each group as a set of "things to
launch or restore" without duplicating windows that are already on screen.

Stock KDE cannot do this from config: the Grouping Plasmoid renders inline and
can't be built from a file, plain Icon widgets are `NoDisplay` and get pruned
from panels, and an Icons-Only Task Manager per group shows every running window
(no launchers-only mode). So this is a small **custom local plasmoid** plus a
declarative config layer.

## Components

- **The widget** — `org.surxe.launchergroup` ("Launcher Group"), a local Plasma 6
  plasmoid.
  - Source in repo: `users/ethan/plasmoids/org.surxe.launchergroup/`
  - Deployed to: `~ethan/.local/share/plasma/plasmoids/org.surxe.launchergroup/`
  - Config keys (`contents/config/main.xml`): `launchers` (comma-separated
    launcher URLs), `groupName` (identity used by the installer), `iconSize`.
  - Behavior (`contents/ui/main.qml`): one `TaskManager.TasksModel` with
    `separateLaunchers:false`, so each app has exactly one row — a launcher row
    (not running) or a window row (running). A row is shown when it is a launcher
    **or** a minimized window, and only for the widget's own apps. Reactive on
    `model.IsMinimized`/`IsWindow`/`IsLauncher`.
- **Deploy installer** — `users/installers/ethan-plasmoids.sh`. Mirrors
  `users/ethan/plasmoids/**` into `~ethan/.local/share/plasma/plasmoids/**`
  (review-gated, 0644). A new/updated plasmoid needs a plasmashell restart to
  register.
- **Config installer** — `users/installers/ethan-taskbar-groups.sh`. Asserts
  config onto **existing** widgets only (never creates/deletes them — creating
  panel widgets from a file is unreliable in Plasma). Matches each Launcher Group
  instance by its `groupName`, sets its `launchers` from the conf, and warns if a
  named widget is missing. Ownership is gated on the plugin id, so a stray marker
  key on a real widget can never make it touch that widget.
- **Declared config** — `users/ethan/kde-taskbar-groups.conf`. Per-monitor
  sections (keyed by kscreen connector), each with `group <Name>` blocks and an
  optional `show-minimized-tasks` directive.

## Set up a new group (one-time, per group)

1. Right-click the target monitor's panel -> Enter Edit Mode -> **Add Widgets**,
   search **"Launcher Group"**, drag it onto the panel.
2. Right-click it -> **Configure Launcher Group** -> set **Group name** (e.g.
   `coding`). Leave **Launchers** blank — the installer fills it.
3. Add the group to `users/ethan/kde-taskbar-groups.conf` under the monitor's
   `[<connector>]` section:
   ```
   [HDMI-A-1]
   group coding
     applications:code.desktop
     applications:org.kde.konsole.desktop
   ```
   (`<connector>` is the output name from `kscreen-doctor -o`.)
4. Deploy: run `users/install.sh` as ethan. It deploys the widget (if changed)
   and asserts each group's launchers, then restarts plasmashell.

Changing a group's shortcuts later is just an edit to the conf + `install.sh`.

## Launcher URL format and the default-app caveat

Launcher URLs use the same vocabulary as `.desktop` launchers:
`applications:<id>.desktop` for menu apps, `file:///…​.desktop` for flatpak
exports.

**Use an explicit `.desktop` id, not a `preferred://` alias.** The widget decides
whether an app has a visible window by matching each launcher to its windows via
an "app key" — the `.desktop` basename without extension, lowercased
(`applications:org.kde.kate.desktop` -> `org.kde.kate`). A `preferred://filemanager`
alias has key `filemanager`, which does not match Dolphin's windows
(`org.kde.dolphin`), so its hide-when-visible logic never fires. Reference the app
directly instead — e.g. the file manager is `applications:org.kde.dolphin.desktop`.

## The empty task manager (DP-left, dp1)

One panel keeps a stock **Icons-Only Task Manager** with **0 pinned launchers**.
The conf's `show-minimized-tasks` directive (under that monitor's section) toggles
`showOnlyMinimized` on that panel's single empty task manager: bare or `true`
surfaces only running-and-minimized windows (a place to restore minimized apps);
`false` shows all windows (a normal task manager). Omitting the directive leaves
the widget untouched. This is stock Plasma, not the custom widget. Currently set
to `false`.

## Current layout

- **HDMI-A-1**: `coding` (code, github-desktop, claude-dev-split, konsole),
  `media` (obs, kdenlive, pinta).
- **DP-2**: `firefox` (dolphin, discord, firefox, steam, my-shortcuts), plus the
  empty task manager (`show-minimized-tasks false` — shows all windows).

The `my-shortcuts` launcher (question-mark icon, no keyboard binding) pops up a
kdialog cheatsheet of every custom shortcut — keyboard bindings, taskbar groups,
and all launchers with their descriptions. It reads the my-system repo at run
time (`users/ethan/localbin/my-shortcuts`), so the list stays accurate as
shortcuts change.

## Files

| Purpose | Path |
| --- | --- |
| Widget package | `users/ethan/plasmoids/org.surxe.launchergroup/` |
| Deploy installer | `users/installers/ethan-plasmoids.sh` |
| Config installer | `users/installers/ethan-taskbar-groups.sh` |
| Declared config | `users/ethan/kde-taskbar-groups.conf` |
| Deployed widget (live) | `~ethan/.local/share/plasma/plasmoids/org.surxe.launchergroup/` |

Restore point for the raw panel config lives outside the repo at
`plasma-org.kde.plasma.desktop-appletsrc` (back it up before large panel changes).
