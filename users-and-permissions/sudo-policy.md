# Sudo policy

The `dev` account is for automation, not interactive use ([users.md](users.md)).
Two narrow, deliberate bridges cross the dev/ethan boundary; both are NOPASSWD and
both are meant to be captured here and deployed by
[`users/install.sh`](../users/install.sh).

## dev -> ethan (account actions only)

One fixed, arg-validated program:

```
dev ALL=(ethan) NOPASSWD: /usr/local/sbin/devscaffold
```

Drop-in: [`system/etc-sudoers.d/devscaffold`](../system/etc-sudoers.d/devscaffold).
`sudo`'s `env_reset` strips dev-supplied env; the wrapper re-asserts `HOME`/`PATH`.
Design and rationale: [development/git-workflow.md](../development/git-workflow.md#authentication).

## ethan -> dev (the devsh bridge)

Ethan may run commands as `dev` without a password. This is what `devsh`
([`users/ethan/.bashrc.d/10-devsh.sh`](../users/ethan/.bashrc.d/10-devsh.sh)) and
every ethan-owned launcher in `~/.local/bin` (e.g. `clip-post`, `wrf-orchestrator`,
`clip-db-pipeline`, `merge-clip-audio`) rely on to hop work to `dev`.

> **TODO — capture the bridge RULE.** The grant itself (the `ethan ALL=(dev)
> NOPASSWD: ...` line) currently lives only in a live `/etc/sudoers.d/` drop-in and
> is not yet tracked in this repo. Recover it (`sudo grep -rl 'ALL=(dev)'
> /etc/sudoers.d/`), then add it as `system/etc-sudoers.d/devbridge` and document it
> here. Do NOT guess it — a wrong rule breaks every `sudo -u dev`.

### env whitelist for the bridge

`env_reset` strips the caller's environment across the hop, so a launcher that must
carry a secret into the dev run needs that variable explicitly whitelisted;
otherwise `sudo` rejects it ("you are not allowed to set the following environment
variables"). The whitelist is additive and lives in
[`system/etc-sudoers.d/devbridge-env`](../system/etc-sudoers.d/devbridge-env):

| Variable | Carried for | Secret source |
|----------|-------------|---------------|
| `STEAM_USERNAME`, `STEAM_PASSWORD` | `wrf-orchestrator` (Exporter Steam login) | `~ethan/.config/wrf-orchestrator/secrets.env` |
| `GH_DATA_REPO_PAT` | `wrf-orchestrator` (Parser data-repo push) | `~ethan/.config/wrf-orchestrator/secrets.env` |
| `CLIP_DISCORD_WEBHOOK` | `clip-post` (Discord webhook upload) | `~ethan/.config/clip-db/secrets.env` |

To let a new dev-run tool carry a secret: add the variable here, redeploy with
`install.sh`, and follow the secret model in
[`users/dev/memory/srv-dev/secrets-for-dev-run-tools.md`](../users/dev/memory/srv-dev/secrets-for-dev-run-tools.md).
If a live drop-in still lists any of these inline, fold it into `devbridge-env` so
the whitelist has a single source.
