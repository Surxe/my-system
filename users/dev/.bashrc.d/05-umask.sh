# --- umask 002: make dev's new files group-writable, so ethan (via the shared
# `developers` group) can edit, commit and push in /srv/dev without a chmod pass.
# Set here rather than via pam_umask: dev's primary group isn't named `dev`, so
# login.defs' USERGROUPS_ENAB never applies, and sudo (how devsh starts dev)
# applies its own 022 anyway. Numbered first so everything after inherits it,
# including Claude sessions launched from this shell.
umask 002
