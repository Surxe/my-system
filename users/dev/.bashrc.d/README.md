# dev's `.bashrc.d/` modules

Sourced by dev's `~/.bashrc` loader. Two sources feed `~dev/.bashrc.d/`, both as a
**copy** and both **additive** (they refresh/add, never prune), so they coexist:

- **Portable fragments** live in the shared `dev-env` repo and are deployed by the
  `dev-env-layer` step (e.g. `10-claude.sh`, the `cc` launcher). They are *not*
  checked in here — they ship to every box.
- **Box-specific fragments** live in *this* dir and are deployed by
  `../../install.sh`'s `dev-bashrc` step (`deploy_dev_bashrc`). Unlike ethan's
  `.bashrc.d/`, these are dev's *own* files — dev already controls its home — so
  there is **no review gate** (same trust model as dev's `CLAUDE.md`/skills).

| File | Source | Contains |
| --- | --- | --- |
| `10-claude.sh` | dev-env (portable) | `cc` launcher (`claude --dangerously-skip-permissions`) as a relaunch loop that pairs with the `new` bin to start a fresh session without inheriting the `/rename` name |
| `15-todo.sh` | this repo (box-specific) | todo cross-box sync env (`TODO_HUB_REMOTE`, `TODO_CLASSIFY_REMOTE`, remote classify cmd) |
| `20-hs.sh` | this repo (box-specific) | `hs` — key-authenticated SSH into the home-server (interactive shell, or `hs cc` to land in Claude on the box) |

Dev's `~/.bashrc` must contain the loader that sources this dir; `dev-env`'s
`deploy_bashrc` adds it on first run if missing:

```bash
if [ -d ~/.bashrc.d ]; then
    for f in ~/.bashrc.d/*.sh; do [ -r "$f" ] && . "$f"; done
    unset f
fi
```
