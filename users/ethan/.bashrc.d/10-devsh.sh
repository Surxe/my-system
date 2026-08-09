# --- Start a shell for the dev user and cd to the dir we were in, otherwise /srv/dev.
# With arguments, run them in that dev shell first, then drop to an interactive
# prompt: e.g. `devsh cc`. The command runs under `bash -ic` so interactive-only
# aliases from dev's ~/.bashrc (like `cc`) resolve.
devsh() {
    local target="$PWD"
    if [ "$#" -gt 0 ]; then
        sudo -u dev bash -ic "cd \"$target\" 2>/dev/null || cd /srv/dev; $*; exec bash"
    else
        sudo -u dev bash -c "cd \"$target\" 2>/dev/null || cd /srv/dev; exec bash"
    fi
}
