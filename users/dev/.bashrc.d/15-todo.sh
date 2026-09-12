# --- todo cross-box sync (dev user).
# The shared todo store syncs to a bare git hub on the home-server. These make the
# dev shell's `todo` hub-aware. Push-on-add itself is handled by the todo-sync.path
# user unit (deployed by users/installers/dev-todo-sync.sh), not the shell.
export TODO_HUB_REMOTE=hub

# Classification runs ONLY on the home-server. On the workstation `todo classify`
# becomes a remote trigger over SSH: it publishes captures, runs the server's drain
# wrapper (pull -> classify -> push), then pulls the new meta back. The alias
# 'todo-hub' (-> dev@home-server) and the real host/IP live only in ~/.ssh/config,
# never committed to this repo.
export TODO_CLASSIFY_REMOTE=todo-hub
export TODO_REMOTE_CLASSIFY_CMD="/srv/dev/repos/home-server/todo/classify-drain.sh"
