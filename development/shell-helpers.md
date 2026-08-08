# Shell helpers (ethan's bash functions)

ethan's `~/.bashrc` defines a set of dev-helper **functions** (not plain aliases)
for the shared `ethan` ↔ `dev` repo workflow. They automate the recurring chore
of: create/clone a repo, apply the shared-file permission model, mark it
git-`safe.directory` for **both** identities, then drop into a `dev` shell.

See the permission model in
[../users-and-permissions/filesystem-permissions.md](../users-and-permissions/filesystem-permissions.md)
and the two-identity git split in [git-workflow.md](git-workflow.md).

## The functions

| Function | Purpose |
| --- | --- |
| `devsh` | Open a shell as the `dev` user, cd'd to `$PWD` (fallback `/srv/dev`). |
| `devperms [dir]` | Fix shared perms on a repo via `sudo /usr/local/sbin/devperms` (defaults to `$PWD`). |
| `devsafe_ethan [dir]` | Idempotently add `dir` to git `safe.directory` for **ethan** (`~/.gitconfig`). |
| `devsafe_dev [dir]` | Same, but for **dev** — runs git as `sudo -u dev -H` so it writes `/home/dev/.gitconfig`. |
| `devclone <profile>/<repo>` | `git clone https://github.com/<profile>/<repo>.git` (HTTPS, **dev** PAT) into `/srv/dev/repos/<repo>`, then perms + both safe-dirs + `devsh`. Repo must already exist on GitHub. |
| `devnew <repo> [--public]` | Create the GitHub remote via `devscaffold` (as ethan), then local `git init -b master` + `remote add origin`, perms + both safe-dirs + `devsh`. |

`devclone` / `devnew` refuse to clobber an existing destination and validate their
argument shape (`devclone` needs a `profile/repo` slug; `devnew` rejects a slug
with `/`).

`devclone` now uses **HTTPS**, matching the classic-PAT `credential.helper store`
auth policy in [git-workflow.md](git-workflow.md) (superseding the earlier
`git@github.com` SSH URL). The clone runs as `dev` with the dev PAT — no ethan
creds involved.

### `devnew` → `devscaffold` (creating the GitHub remote)

`devnew` no longer just `git init`s a bare local repo — it creates the matching
remote under `Surxe`, grants `Surxe-dev` push access, and applies the `master`
ruleset. Those account-side actions need **ethan's** PAT, so `devnew` calls the
root-owned wrapper `/usr/local/sbin/devscaffold` via a narrow `sudo -u ethan` rule:

```bash
url="$(sudo -u ethan -H /usr/local/sbin/devscaffold "$reponame" "${2:-}")" || return 1
git init -b master "$dest"
git -C "$dest" remote add origin "$url"
```

The wrapper touches nothing under `/srv/dev`; everything local stays on the dev
identity. Full script, sudoers rule, and rationale (including why an ambient
`dev`-readable credential helper is the wrong model) live in
[git-workflow.md → Programmatic repo scaffolding](git-workflow.md#programmatic-repo-scaffolding-devscaffold).

## Layout: `~/.bashrc.d/`

The functions are factored out of `.bashrc` into topical files sourced by a small
loader. This keeps `.bashrc` to shell boilerplate and makes each helper easy to
find and edit.

Loader in `~/.bashrc`:

```bash
# --- source modular shell config ---
if [ -d ~/.bashrc.d ]; then
    for f in ~/.bashrc.d/*.sh; do
        [ -r "$f" ] && . "$f"
    done
    unset f
fi
```

Files in `~/.bashrc.d/`:

| File | Contains |
| --- | --- |
| `10-devsh.sh` | `devsh` |
| `20-devperms.sh` | `devperms` |
| `30-devsafe.sh` | `devsafe_ethan`, `devsafe_dev` |
| `40-devrepo.sh` | `devclone`, `devnew` |

**Numeric prefixes are cosmetic.** Sourcing only *defines* functions; bash
resolves the names a function calls (e.g. `devclone` → `devperms`) at **call**
time, by which point every file has been sourced. Order would only matter if a
file *executed* code at source time that depended on another file — none of these
do. Prefixes are kept purely as human-facing ordering and as cheap insurance if
such a file is ever added.

## Notes

- These live in `.bashrc.d/` rather than `~/.bash_aliases` because they are
  functions; `~/.bash_aliases` is still fine for plain `alias x=…` lines.
- Applied by ethan directly — the `dev` user cannot write ethan's home.
