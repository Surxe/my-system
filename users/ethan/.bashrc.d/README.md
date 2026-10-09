# ethan's `.bashrc.d/` modules

Deployed by `../../install.sh` into `~ethan/.bashrc.d/` (copy, with diff+confirm —
these run **as ethan**, so they are privileged). Sourced by ethan's `~/.bashrc`
loader. See `development/shell-helpers.md`.

| File | Status | Contains |
| --- | --- | --- |
| `10-devsh.sh` | present | `devsh` |
| `20-devperms.sh` | present | `devperms` (the shell wrapper that calls `sudo /usr/local/sbin/devperms`) |
| `30-devsafe.sh` | present | `devsafe_ethan`, `devsafe_dev` (the repo and its submodules), `devsafe_paths` |
| `40-devrepo.sh` | present | `devrepo` (`new`/`clone`), `devaccept` |
| `50-localbin.sh` | present | `~/.local/bin` on `PATH` |
