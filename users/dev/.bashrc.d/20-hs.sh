# --- hs: open a key-authenticated SSH session on the home-server (as dev).
# Lands in /srv/dev (the shared work root, already a trusted Claude folder), not
# dev's /home/dev — so `hs cc` doesn't hit Claude's folder-trust prompt. With no
# args it drops to an interactive shell there; any args are run there instead,
# inside an interactive bash so dev's shell aliases resolve — e.g. `hs cc` jumps
# straight into a Claude session on the server (the idiom mirrors `devsh`, which
# also cds to /srv/dev). A Claude terminal launcher can call `hs` for a shell or
# `hs cc` to land in Claude on the server.
#
# Auth, host and IP all come from dev's ~/.ssh/config (the 'home-server' alias:
# IdentityFile id_todo, IdentitiesOnly) — key-based, no password — so nothing
# sensitive lives in this repo; this is just the thin, memorable entrypoint over
# that config. Reuses the same alias/key already used for todo hub sync.
hs() {
    if [ "$#" -gt 0 ]; then
        # cd to /srv/dev, then mirror `devsh`: run the command and drop to an
        # interactive remote shell (`exec bash`) instead of closing the
        # connection. This keeps a tmux pane running `hs cc` alive as a
        # home-server shell after Claude exits, exactly as `devsh cc` does.
        ssh -t home-server "bash -ic 'cd /srv/dev 2>/dev/null; $*; exec bash'"
    else
        ssh -t home-server "bash -ic 'cd /srv/dev 2>/dev/null; exec bash'"
    fi
}
