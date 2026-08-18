# dev's `localbin/` — PATH executables

Deployed by `../../install.sh` (`installers/dev-bin.sh`, step `dev-bin`) into
`~dev/.local/bin/` as a **copy**, mode `0755`. These are dev's *own* files — dev
already controls its home — so there is **no review gate** (same trust model as
dev's `.bashrc.d/`, `CLAUDE.md`, and skills). `~/.local/bin` is on dev's PATH via
Debian's stock `~/.profile` (the same dir `todo` lands in via `todo-dev`).

The installer is additive: it refreshes/adds executables but does **not** prune
bins removed from the repo, so deleting one here also means removing the deployed
copy from `~dev/.local/bin/` by hand.

_No executables are currently defined here._
