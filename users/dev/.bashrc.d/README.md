# dev's `.bashrc.d/` modules

Deployed by `../../install.sh` (`deploy_dev_bashrc`) into `~dev/.bashrc.d/` as a
**copy**. Unlike ethan's `.bashrc.d/`, these are dev's *own* files — dev already
controls its home — so there is **no review gate** (same trust model as dev's
`CLAUDE.md`/skills). Sourced by dev's `~/.bashrc` loader.

| File | Contains |
| --- | --- |
| `10-claude.sh` | `cc` launcher (`claude --dangerously-skip-permissions`) as a relaunch loop that pairs with the `new` bin (see `../localbin/`) to start a fresh session without inheriting the `/rename` name |

Dev's `~/.bashrc` must contain the loader that sources this dir:

```bash
if [ -d ~/.bashrc.d ]; then
    for f in ~/.bashrc.d/*.sh; do [ -r "$f" ] && . "$f"; done
    unset f
fi
```

The stock `~dev/.bashrc` itself is not managed by this repo; the loader above is
a one-time bootstrap added when `10-claude.sh` was first introduced.
