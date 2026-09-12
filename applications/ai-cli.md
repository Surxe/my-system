# AI CLI tools

Terminal AI coding agents. Installed as **npm global packages** (nvm-managed,
under `~/.nvm/versions/node/<ver>/bin/`), so they are **not** tracked by
`scripts/inventory.sh` (which only reads `apt-mark showmanual` / `flatpak list`) —
record them here manually.

## DeepSeek Harness (`dsh`) + dsh-TUI

- **What:** `@deepseek-ai/dsh` is the official DeepSeek Harness (the model-to-
  filesystem agent loop; profile launcher, ships `web` + `headless` profiles).
  `@deepseek-harness-tui/dsh-tui` is a community (MIT) Claude-Code-style
  interactive terminal UI, mounted as the `dsh-tui` profile. Not official DeepSeek.
- **Installed:** globally via `npm install -g @deepseek-ai/dsh @deepseek-harness-tui/dsh-tui`.
  Requires Node `^22.19 || >=24` (nvm) and `pnpm` (via `corepack enable pnpm`) for
  profile plugin management.
- **Profile data:** `~/.dsh/profiles/dsh-tui/` (the mounted TUI plugin).
- **Commands on PATH:** `dsh` (base), `dsh-tui` and `dst` (TUI launcher, aliases).

### Launch

```sh
DEEPSEEK_API_KEY=<your-key> dsh-tui      # or: dst
```

The `DEEPSEEK_API_KEY` is a secret — keep it in Ethan's shell env, never in this
repo. Equivalent invocation: `dsh --profile dsh-tui`.

### Maintenance

```sh
# update
npm update -g @deepseek-ai/dsh @deepseek-harness-tui/dsh-tui

# update just the TUI profile plugin
dsh plugin --profile dsh-tui add @deepseek-harness-tui/dsh-tui@latest

# remove
npm uninstall -g @deepseek-ai/dsh @deepseek-harness-tui/dsh-tui
rm -rf ~/.dsh/profiles/dsh-tui
```
