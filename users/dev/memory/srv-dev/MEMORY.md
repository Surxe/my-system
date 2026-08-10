# Memory index

- [MangoHud Debian no-NVML](mangohud-debian-no-nvml.md) — Debian's mangohud lacks NVML → NVIDIA GPU% stuck at 0%; fix is upstream install
- [BT headphone X11 relink](bt-headphone-x11-relink.md) — "X11" headphone page-timeouts on Debian after Windows use; remove + re-pair fixes it
- [Repos location](repos-location.md) — new git repos/projects go under /srv/dev/repos (root isn't writable by dev)
- [steam-price-tracker venv](steam-tracker-venv.md) — run python/pytest via .venv/bin/python in that repo
- [Clip-tagging MCP](clip-tagging-mcp.md) — gaming-clip tag+query MCP: stack decisions, runs on Linux dev box (clips synced from Windows)
- [WGU AI masters plan](wgu-ai-masters-plan.md) — enrolling in WGU M.S. SWE (AI) funded by Nelnet tuition assistance; plan in /srv/dev/repos/wgu-ai-masters
- [ethan bashrc aliases](ethan-bashrc-aliases.md) — ethan's dev-helper shell functions (devsh/devperms/devclone/…), split into ~/.bashrc.d/; documented in system-context repo
- [No auto-memory without consent](no-auto-memory-without-consent.md) — never auto-write memories; propose to Ethan; edit the repo copy (my-system) not live
- [No emojis in files](no-emojis-in-files.md) — never use emojis/emoticons in written files; chat only
- [Bashrc edit workflow](bashrc-edit-workflow.md) — edit .bashrc.d helpers in the my-system repo (dev-writable), then ask before commit + remind to run install.sh
- [GitHub auth as dev](github-auth-as-dev.md) — gh is persistently authed as dev (hosts.yml); call gh directly, no GH_TOKEN
- [No symlink repo→home](no-symlink-repo-to-home.md) — never symlink dev-writable repo files into Ethan's home; install.sh must COPY (privilege boundary)
- [todo command = no action](todo-command-no-action.md) — `todo` CLI calls are Ethan logging, not requests; don't act/spend tokens unless explicitly asked
- [User-specific via my-system](user-specific-via-my-system.md) — new skills/aliases/shortcuts/statusbars go in my-system + install.sh, never edited in user files directly
