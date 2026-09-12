# --- hs: open a key-authenticated SSH session on the home-server (as dev).
# With no args it drops to an interactive login shell on the box; any args are run
# there instead, inside an interactive bash so dev's shell aliases resolve — e.g.
# `hs cc` jumps straight into a Claude session on the server (the idiom mirrors
# `devsh`). A Claude terminal launcher can call `hs` for a shell or `hs cc` to land
# in Claude on the server.
#
# Auth, host and IP all come from dev's ~/.ssh/config (the 'home-server' alias:
# IdentityFile id_todo, IdentitiesOnly) — key-based, no password — so nothing
# sensitive lives in this repo; this is just the thin, memorable entrypoint over
# that config. Reuses the same alias/key already used for todo hub sync.
hs() {
    if [ "$#" -gt 0 ]; then
        ssh -t home-server "bash -ic '$*'"
    else
        ssh home-server
    fi
}
