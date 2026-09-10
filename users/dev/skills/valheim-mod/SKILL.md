---
name: valheim-mod
description: >-
  Add, update, or remove a BepInEx mod for Valheim on this workstation. Shares
  the game/BepInEx paths, the dev->ethan privilege boundary (stage in scratch,
  hand ethan a `!bash` command), and the Thunderstore resolve/download/verify
  flow. Use whenever Ethan wants to install, update, or remove a Valheim mod.
---

# Add / update / remove a Valheim mod

Valheim is native-Steam, modded with BepInEx (denikson pack). The game dir is in
**ethan's home**, which `dev` cannot read or write — so `dev` stages files in
shared scratch and ethan runs the copy via `!bash`.

## Paths (the whole point of this skill)

- **Game dir:** `/home/ethan/.steam/steam/steamapps/common/Valheim`
  (fallback autodetect: `$HOME/.local/share/Steam/...`, and Steam
  `libraryfolders.vdf` extra libraries).
- **Plugins:** `<game>/BepInEx/plugins/` — mod DLLs go here (BepInEx loads them
  recursively; flat is fine).
- **Config:** `<game>/BepInEx/config/` — per-mod `.cfg`, generated on first run.
  Leave these alone on updates.
- **Loader/core** (only touched for a BepInEx-pack update): `<game>/BepInEx/core/`,
  `doorstop_*`, `start_game_bepinex.sh`, `start_server_bepinex.sh`, `winhttp.dll`.
- **Staging (dev-writable, shared):** `/srv/dev/scratch/valheim-mods/`
  (`zips/`, `extract/`, `staged-plugins/`). Author install/remove scripts here.

## Boundary

`dev` never writes ethan's home. Do the download/extract/hash as `dev` in
scratch, write a small script to `/srv/dev/scratch/valheim-mods/`, then tell
ethan to run it in his own session:

```
!bash /srv/dev/scratch/valheim-mods/<script>.sh
```

The scripts locate the game dir themselves (see the `find_valheim` pattern in the
existing scripts under that dir) and copy from `staged-plugins/`.

## Resolve a mod (Thunderstore)

Version, dependencies, and download URL come from the API — don't guess:

```
curl -sL https://valheim.thunderstore.io/api/v1/package/ -o /tmp/ts_pkgs.json
# then grep/parse full_name "<Namespace>-<Name>", versions[].version_number,
# download_url, dependencies.
```

Download URL pattern: `https://thunderstore.io/package/download/<Namespace>/<Name>/<Version>/`

For each package: unzip, find the `*.dll` (root or `plugins/`), copy into
`staged-plugins/`, and record `sha256sum`. Verify the BepInEx-pack dependency is
satisfied by the installed build (currently `5.4.2350`); an older declared dep is
fine.

## Install / update / remove

- **Install or update:** copy the DLL(s) into `BepInEx/plugins/` (overwrites the
  old version in place). Configs are untouched.
- **Remove:** delete the mod's DLL(s) from `plugins/` and any orphaned
  `config/<mod>.cfg`. Watch dependency libs — remove **Jotunn** only if nothing
  else needs it.
- Always print plugins before/after and the sha256 so ethan can verify.

## ModSentry note

If a dedicated server with ModSentry is in play, the client mod set must match the
server's `BepInEx/config/ModSentry_Required` / `_Optional` policy folders
(compared by plugin id + version + **exact DLL hash**). Any change to the client
DLL set — add, update, or remove — means updating those folders with the same
staged DLLs, or clients get kicked. See `SERVER-HANDOFF.md` in the staging dir.

## Constraints

- Don't run the install scripts yourself; hand ethan the `!bash` command.
- Pin exact versions and keep the sha256 in the script for verification.
- No emojis in the scripts/files (chat only).
