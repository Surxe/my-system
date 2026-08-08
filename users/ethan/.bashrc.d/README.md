# ethan's `.bashrc.d/` modules

Deployed by `../../install.sh` into `~ethan/.bashrc.d/` (copy, with diff+confirm —
these run **as ethan**, so they are privileged). Sourced by ethan's `~/.bashrc`
loader. See `development/shell-helpers.md`.

| File | Status | Contains |
| --- | --- | --- |
| `10-devsh.sh` | **TODO — add from live** | `devsh` |
| `20-devperms.sh` | **TODO — add from live** | `devperms` (the shell wrapper that calls `sudo /usr/local/sbin/devperms`) |
| `30-devsafe.sh` | **TODO — add from live** | `devsafe_ethan`, `devsafe_dev` |
| `40-devrepo.sh` | present | `devrepo` (`new`/`clone`), `devaccept` |

`10/20/30-*.sh` are not yet checked in: they live only in ethan's `700` home, which
`dev` (and Claude) cannot read, so they could not be captured automatically. Ethan
should copy the live files in here once, e.g.:

```bash
cp ~/.bashrc.d/{10-devsh,20-devperms,30-devsafe}.sh \
   /srv/dev/repos/my-system/users/ethan/.bashrc.d/
```

Until then `install.sh` deploys only `40-devrepo.sh`; the others remain whatever is
already in ethan's home.
