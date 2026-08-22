# Groups

## `developers`

Shared access between:

- `ethan`
- `dev`
- development tooling

Used to share everything under `/srv/dev`. The permission convention that makes
this work (setgid inheritance) is in
[filesystem-permissions.md](filesystem-permissions.md).

> Confirm membership with `getent group developers` (run by `scripts/inventory.sh`).

## `render` and `video` (for `dev`)

`dev` is a member of `render` and `video` so it can open the GPU device nodes
(`/dev/dri/renderD128`, group `render`; `/dev/dri/card0`, group `video`). This is
required by the **WRFrontiersDB-Orchestrator** mapper stage: it launches War
Robots Frontiers under Proton via `gamescope --backend headless`, which still
renders on the NVIDIA GPU offscreen and therefore needs the render node. Without
this membership the mapper had to be run as `ethan` (the only other GPU-group
member); granting it to `dev` lets the whole patch-day pipeline run unattended as
`dev`.

Two supporting pieces go with the group grant:

- **Linger** — `dev` has no interactive login session, so it has no
  `XDG_RUNTIME_DIR`. `loginctl enable-linger dev` creates a persistent
  `/run/user/1001`, which the mapper stage exports as `XDG_RUNTIME_DIR`.
- **gamescope** — already installed system-wide (apt package, at
  `/usr/games/gamescope`), but `/usr/games` is **not** on `dev`'s `PATH`, so
  `shutil.which("gamescope")` returns `None` for `dev`. The orchestrator's mapper
  stage prepends `/usr/games` to the subprocess `PATH` rather than changing
  `dev`'s login PATH. No install needed.

Root commands (run once, by a sudo user — `dev` has no sudo, see
[sudo-policy.md](sudo-policy.md)):

```bash
sudo usermod -aG render,video dev     # GPU device-node access
sudo loginctl enable-linger dev       # persistent /run/user/1001 for XDG_RUNTIME_DIR
```

Group changes apply to **new** `dev` processes only, so the orchestrator must be
started after the change (an existing `dev` shell won't have the groups). `sg`
only carries one supplementary group, so testing from a pre-grant session needs
`sudo -u dev` (a fresh `initgroups`) to get `render` **and** `video` together.

### Validated (2026-08-22)

Confirmed working as `dev` on the RTX 5070 with:

```bash
sudo -u dev env -i HOME=/home/dev XDG_RUNTIME_DIR=/run/user/1001 \
  PATH=/usr/games:/usr/bin:/bin \
  gamescope --backend headless -W 1280 -H 720 -- <child>
```

gamescope's headless backend initializes fully (Vulkan picks the NVIDIA device,
compositor + Xwayland come up, the child runs). It then **segfaults on teardown**
(`failed to read Wayland events: Broken pipe`, exit 139) — a known
gamescope-on-NVIDIA teardown crash. This is harmless for the mapper: UE4SS writes
the `.usmap` and exits the game before teardown, and the exporter keys success off
the `.usmap` existing, not the launcher exit code
(`WRFrontiers-Exporter/src/mapper/linux_mapper.py`). No exporter change is needed.

> **Security tradeoff (deliberate):** `dev` is the repo-writable, AI-touched
> account. Adding it to `render`/`video` widens its reach to the GPU. Accepted
> because the mapper genuinely needs the GPU and the alternative (running
> repo-writable code as `ethan`) is worse. `dev` still has no sudo.
>
> Confirm membership with `getent group render video` or `id dev`.
