# users/ + system/ — per-user and host config, with a deploy script

Version-controlled config for this machine, deployed to live locations by
[`install.sh`](install.sh). Structured by **trust tier** because the repo is
dev-writable but some files run as ethan or root.

```
users/
  install.sh        # deploys everything (run as ethan for all tiers; as dev for dev-tier)
  dev/              # dev-tier: dev's own config (moved from the old dev-user repo)
                    #   build-claude-md.sh assembles CLAUDE.md; install.sh copies it
  ethan/            # ethan-tier: files sourced by ethan's shell (run AS ethan)
    .bashrc.d/      #   devrepo/devaccept (40) + TODO 10/20/30 (see its README)
    .config/devscaffold/token.example   # real `token` is gitignored (secret)
../system/          # root-tier: installed to /usr/local/sbin + /etc/sudoers.d as root
```

## Deploy

```bash
./install.sh          # as ethan: root-tier (sudo) + ethan-tier + dev-tier
./install.sh          # as dev:   dev-tier only
```

## Trust model (read before trusting this)

`install.sh` copies privileged (ethan/root) files **from the working tree**, which
`dev` can write. So the GitHub merge gate alone does **not** protect against a local
edit landing in ethan/root on the next deploy. `install.sh` mitigates this with a
**review gate**: each privileged file is diffed against the ethan-approved
`origin/master` and needs explicit confirmation if it differs. This narrows but does
not close the window — a deliberate trade-off (see
[`../development/git-workflow.md`](../development/git-workflow.md)).

- **dev-tier** files (dev's own, e.g. `CLAUDE.md`) are **copied** into dev's home —
  no review gate (dev already controls its own home). Re-run `install.sh` after
  rebuilding `CLAUDE.md` to refresh the deployed copy.
- **ethan/root-tier** files are also **copied** (never symlinked from this
  dev-writable tree) and pass the review gate first.
