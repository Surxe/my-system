---
name: install
description: >-
  Standard process for installing a new application or package on this Debian
  workstation. Resolves the best install method with an apt → flatpak → upstream
  preference ladder and hands the user chunked copy/paste commands to run (the
  dev user has no sudo). Use whenever the user wants to install software.
---

# Install an application or package

The standard process for adding new software to this Debian 13 "Trixie" /
KDE Plasma / Wayland / NVIDIA workstation.

## Hard constraints — read first

- **You have no sudo.** Claude runs as the unprivileged `dev` user and can never
  run the install itself. Your job is to **resolve the right method and paste
  the privileged commands in chunks** for the user to run.
- **Run read-only probes yourself; hand off anything privileged or
  system-changing.** The availability checks (`apt-cache policy`, `apt search`,
  `flatpak search`) and post-install version checks are read-only and permitted
  for the `dev` user — run them directly with the Bash tool. Everything that
  needs `sudo` or mutates the system (installs, repo/keyring setup,
  `apt-get update`) you present prefixed with `!` for the user to run, then wait
  for and verify their output before sending the next chunk.
- **Do not edit the repo.** This skill does not touch `applications/installed.md`,
  the category files, or anything else in the repo. Install-only.
- **Never touch secrets** — SSH keys, passwords, API tokens, backup credentials
  (see `CLAUDE.md` "Never access").
- **Explain impact before any system-changing command** (per `CLAUDE.md`). If the
  package is unusual or non-Debian, say so and get agreement before proceeding.

## Step 1 — Identify and confirm the target

Clarify the exact app or package the user means. If the name is ambiguous or the
package looks unusual / non-Debian, surface that and get agreement before going on.

## Step 2 — Resolve availability down the strict ladder

Check each tier in order and **stop at the first tier that has the package.**
Prefer apt, then flatpak, then upstream — do not skip ahead for convenience.

**Tier 1 — apt (preferred).** Run the read-only probe yourself (Bash tool):

```
apt-cache policy <pkg>
```

If you don't know the exact package name, search first:

```
apt search <term>
```

If apt has it → Tier 1 wins. Go to Step 3.

**Tier 2 — flatpak / flathub.** Only if apt has nothing — run yourself:

```
flatpak search <term>
```

If flathub has it → Tier 2 wins. Go to Step 3.

**Tier 3 — upstream website.** Only if neither apt nor flatpak has it. Prefer, in
order: a vendor `.deb`, then an AppImage, then a vendor install script. This tier
means the app **won't auto-update with the system** — explain that update story
and get agreement before continuing.

## Step 3 — Report the finding and impact

Before pasting any install command, tell the user:

- which tier won and why,
- the version it provides, and
- if apt's version is notably stale versus a newer flatpak/upstream build, the
  version delta — so the user can choose to override the ladder.

Default behavior stays: **strict ladder, apt wins if present.** Only deviate if the
user asks.

## Step 4 — Hand over the install commands in chunks

One logical action per block. Label each block with what it does and what to look
for in the output. Send the next chunk only after verifying the previous output.

### apt path

Two steps. Use `apt-get`, **without `-y`** — the interactive confirmation is the
impact-review gate, and the user answers it.

```
! sudo apt-get install --simulate <pkg>
```

Have the user review the simulated plan. Then:

```
! sudo apt-get install <pkg>
```

(The user answers the `y/N` prompt themselves.)

### apt path with a third-party repository (only when required)

Use the modern keyring convention — **not** the deprecated `apt-key`. Discrete,
verifiable chunks:

```
! sudo install -m 0755 -d /etc/apt/keyrings
```

```
! curl -fsSL <vendor-key-url> | sudo gpg --dearmor -o /etc/apt/keyrings/<name>.gpg
```

```
! echo "deb [signed-by=/etc/apt/keyrings/<name>.gpg] <repo-url> <suite> <component>" | sudo tee /etc/apt/sources.list.d/<name>.list
```

```
! sudo apt-get update
```

```
! sudo apt-get install <pkg>
```

### flatpak path

Ensure the flathub remote exists, then install:

```
! flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

```
! flatpak install flathub <app-id>
```

Note any KDE / Wayland / NVIDIA portal or theming caveats relevant to the app.

### upstream path

1. Download the artifact.
2. **Verify it** — checksum and/or GPG signature whenever the vendor provides one.
3. Install:
   - `.deb`: `! sudo apt-get install ./<file>.deb`
   - AppImage: place it in a stable location (e.g. `~/Applications`), make it
     executable, and add a `.desktop` entry.
4. Tell the user where the binary lives and how to update it later.

## Step 5 — Verify the install

Confirm success from a version or launch check. For a system-wide CLI binary
this is read-only — run it yourself (Bash tool):

```
<cmd> --version
```

For flatpak apps (they run in the user's session), have the user run it and paste
the output:

```
! flatpak run <app-id> --version
```

## Step 6 — Close out (no repo writes)

This skill does not update documentation. **Remind** the user (do not do it
yourself) that:

- `applications/installed.md` and the relevant category file are not updated, and
- `scripts/inventory.sh` regenerates the authoritative package list
  (`apt-mark showmanual`, `flatpak list`).

## Command-hygiene checklist

- One logical action per pasted block; label it and say what to look for.
- Run read-only probes/version checks yourself (Bash); prefix only the
  privileged, system-changing commands with `!` for the user to run.
- No interactive flags (e.g. `-i`); `apt-get` without `-y` on purpose.
- Never run the privileged install yourself — you only paste.
- Never touch secrets or keys.
