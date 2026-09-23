# Memory index — my-system (project: /srv/dev)

Workstation-local memories only. Universal memories (shared across both boxes, deployed from `dev-env`) live in `~dev/.agents/memory/` (symlinked to `~dev/.claude/projects/-srv-dev/memory`) after `dev-env/install.sh` runs — see the `edit-in-repo` memory for the deploy model.

- [Active box](active-box.md) — you're on the workstation (hostname `ethan-debian`); box-local memory = box identity
- [MangoHud Debian no-NVML](mangohud-debian-no-nvml.md) — Debian's mangohud lacks NVML → NVIDIA GPU% stuck at 0%; fix is upstream install
- [BT headphone X11 relink](bt-headphone-x11-relink.md) — "X11" headphone page-timeouts on Debian after Windows use; remove + re-pair fixes it
- [steam-price-tracker venv](steam-tracker-venv.md) — run python/pytest via .venv/bin/python in that repo
- [Clip-tagging MCP](clip-tagging-mcp.md) — gaming-clip tag+query MCP: stack decisions, runs on Linux dev box (clips synced from Windows)
- [WGU AI masters plan](wgu-ai-masters-plan.md) — enrolling in WGU M.S. SWE (AI) funded by Nelnet tuition assistance; plan in /srv/dev/repos/wgu-ai-masters
- [ethan bashrc aliases](ethan-bashrc-aliases.md) — ethan's dev-helper shell functions (devsh/devperms/devclone/…), split into ~/.bashrc.d/; documented in system-context repo
- [Bashrc edit workflow](bashrc-edit-workflow.md) — edit .bashrc.d helpers in the my-system repo (dev-writable), then ask before commit + remind to run install.sh
- [No symlink repo→home](no-symlink-repo-to-home.md) — never symlink dev-writable repo files into Ethan's home; install.sh must COPY (privilege boundary)
- [todo done command](todo-done-command.md) — mark a todo complete with `todo done <id>`; reopen/rm round out the lifecycle
- [tts command = no action](tts-command-no-action.md) — `!tts` shell calls are Ethan driving TTS; stay silent, don't act
- [User-specific via my-system](user-specific-via-my-system.md) — new skills/aliases/shortcuts/statusbars go in my-system + install.sh, never edited in user files directly
- [my-system generated files](my-system-generated-files.md) — my-system PRs often show auto-gen diffs in users/dev/CLAUDE.md + sections/repo-descriptions.md; edit blueprint/generators, not output
- [Secrets for dev-run tools](secrets-for-dev-run-tools.md) — dev-run tool secrets live in ethan's space (dev can't read at rest), injected via an ethan launcher; never parked in ~dev
- [WRF data structure](wrf-data-structure.md) — WRFrontiersDB data layout: /srv/dev/wrf/data working tree, the published Data repo, and icon_path resolution
