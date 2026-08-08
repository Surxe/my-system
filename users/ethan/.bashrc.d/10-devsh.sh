# --- Start a shell for the dev user and cd to the dir we were in, otherwise /srv/dev
devsh() {
    local target="$PWD"
    sudo -u dev bash -c "cd \"$target\" 2>/dev/null || cd /srv/dev; exec bash"
}
