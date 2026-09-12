# Shared config layer across boxes (my-system + home-server)

Status: **explored, not yet planned/built.** This is a design record of a
brainstorm, not a settled decision. It captures the options weighed and Ethan's
positions so a later `/plan` starts from an explored place. The related but
separate cross-box **todo** sync work is being planned on its own (it reuses the
same private link between the boxes); see [future-plans.md](future-plans.md).

## Problem

There are now two mature, symmetric machine repos, each with its own
`install.sh` and its own deployed Claude context (skills, memory, `CLAUDE.md`):

- **my-system** — this workstation (dual-boot, KDE, gaming, `ethan`/`dev`/`root`
  trust tiers). Deploys `users/dev/skills/*`, `users/dev/memory/srv-dev/*`, the
  `cc` launcher, git identity, statusline, etc.
- **home-server** (`Surxe/home-server`) — a Proxmox Debian box, **no KDE,
  `dev`-only** (home-dev), but it wants the same PR review flow the `pr`/`merged`
  skills give. It already deploys its own `claude/skills/*`,
  `claude/memory/home-dev/*`, and `claude/CLAUDE.md` by the same pattern.

The portable "my dev ergonomics" (the `pr`, `merged`, `brainstorm`, `install`
skills; the `cc` alias; universal memories; git author identity; statusline)
are currently **duplicated-or-missing** across the two repos. Goal: share as
much of that logic as possible, and make each shareable item
(skills, memories, bins, aliases) **configurably box-specific** — shared by
default, excludable per box.

## The key framing: three buckets, not two

Because home-server is already a peer machine repo (not a bare box to copy to),
the content splits three ways:

1. **Shared dev layer** — travels to every box: `pr`, `merged`, `brainstorm`,
   `install` skills; `cc`; git identity; statusline; universal memories
   (`no-emojis`, `no-symlink`, `github-auth-as-dev`, `memory-files-edit-in-repo`).
2. **Workstation-only** — the rest of my-system (KDE, gaming, plasmoids, desktop
   entries, `ethan`/`root` trust tiers).
3. **Server-only** — the rest of home-server (Proxmox, Valheim,
   `home-server-install`, `restart-valheim`).

The thing that deserves to be centrally managed is **bucket 1**, not a single
machine repo.

## Options weighed

| Option | Idea | Pro | Con |
| --- | --- | --- | --- |
| **A. Separate shared repo** (`dev-env`) | bucket 1 moves to its own repo; each machine repo consumes it as a sibling clone | server clones a tiny clean surface; clear ownership | a second repo + sync dance |
| **B. One repo, host profiles** | `install.sh` learns `--profile workstation\|server`; portable installers run on both, machine-specific gated | single source of truth; reuses `install.sh` | server carries workstation cruft it ignores |
| **C. Scope-tag installers** | each `installers/*.sh` declares `SCOPE=portable\|workstation`; filter the `INSTALLERS` array | tiny diff; matches existing installer design | profile logic inside a monolith |
| **D. Thin leaf-copy** | server runs a tiny script that pulls just the named files, no `common.sh`/gate | trivial to stand up | no gate, no builders, drifts |
| **E. Skills as a Claude Code plugin** | `pr`/`merged`/etc. become an installable plugin; enable/disable per box | native; versioned; per-box enable IS the profile | covers only skills/commands/hooks/MCP — not `cc`, memory, gitconfig, bins |

## Ethan's positions (captured verbatim-ish)

- Initially preferred **two separate repos**, but floated: "both cloned on each
  and there's an env for each saying what skills to exclude (all default to yes);
  same for memories and other stuff like aliases." (A default-include,
  per-host-exclude model.)
- Then leaned toward **one monolithic profile within my-system** that decides
  which PC takes which skills/memories/etc., checked in and managed centrally.
- Asked how the central-profile idea **scales to the plugin idea**, and whether
  the real recommendation is **one repo for all of "my" things** plus a profile
  saying which PC each item is used on — i.e. an interest in **eventually
  combining the two machine repos**.

## How the profile idea and the plugin idea relate

For **skills specifically, the plugin model *is* the profile**: a Claude Code
plugin is a git repo, each box installs it, and Claude Code's native per-box
enable/disable is exactly "which PC gets which skill" — for free, instead of a
bespoke `EXCLUDE_SKILLS` loop.

The catch is **scope**: a plugin covers only skills, slash-commands, hooks, and
MCP. It does **not** carry `cc` (a bash function), memory files, git identity,
or `bin` executables. So a plugin can own the *skills slice* but cannot replace
the installer for everything else. Packaging is also the easy half: `pr`/`merged`
break on any box without `todo` + gh-as-dev regardless of how the skill file got
there, so the real portability work is the cross-repo dependencies, not the
delivery mechanism.

## Where it landed (recommendation, not yet committed)

- **Do not fold everything into a single my-system monolith now.** my-system is
  semantically the workstation, and home-server already exists as a peer repo; a
  true monolith would drag Proxmox/Valheim deploy logic into "my dual-boot
  system" repo, or leave home-server split out anyway (so the "one repo" goal is
  not actually met).
- **Recommended shape: a small shared `dev-env` repo (Option A), consumed by
  both machine repos** as a sibling clone. The per-box profile/exclusion lives
  there as a host manifest with **default-include, per-host exclude**:

  ```
  dev-env/
    skills/            pr, merged, brainstorm, install, cc-fragment, ...
    memory/            universal memories only
    install.sh         deploys skills+memory+cc for THIS host
    hosts/
      workstation.env  EXCLUDE="..."   # default = include all
      proxmox.env      EXCLUDE="..."
  ```

  Each machine repo shrinks to machine-specific only and calls
  `../dev-env/install.sh --host <name>` as one deploy step.
- **Adopt the plugin only for the skills slice** once `dev-env` exists and the
  skill count justifies it — treat it as an upgrade to the skills directory, not
  as the thing that replaces the installer.

## Eventually combining the repos (open direction)

Ethan is interested in one repo for all "my" things. The `dev-env` layer is
compatible with that end-state either way: it can stay a thin shared layer, or
later absorb the machine repos under one roof with a host profile (Option B/C)
selecting per-box content. The shared layer is the low-regret first step — it
centralizes the duplicated logic now without forcing the bigger "merge
everything" decision, and keeps that door open. Revisit a full combine once the
shared layer has proven the profile model in practice.

## Open questions (to resolve before `/plan` on this)

- `dev-env` as a plain clone-and-copy repo, or go plugin-for-skills from day one?
- Universal memories as a hand-curated dir, or a `scope:` frontmatter tag filtered
  at deploy?
- Cross-repo deps on a headless server: confirm `todo` + gh-as-dev are present so
  `pr`/`merged` actually work there (this overlaps the separate todo sync work).
- Should `dev/build-claude-md.sh` emit a **host-specific** `CLAUDE.md` so a
  headless box is not full of KDE/gaming facts?
