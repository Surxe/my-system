# --- mark a repo as git safe.directory for THIS user (idempotent) ---
devsafe_ethan() {
    local dir; dir="$(readlink -f -- "${1:-$PWD}")" || return 1
    git config --global --get-all safe.directory | grep -qxF "$dir" \
        || git config --global --add safe.directory "$dir"
}

# --- mark a repo as git safe.directory for the DEV user (idempotent) ---
# Runs git as dev via sudo -H so it writes /home/dev/.gitconfig, not ethan's.
devsafe_dev() {
    local dir; dir="$(readlink -f -- "${1:-$PWD}")" || return 1
    sudo -u dev -H git config --global --get-all safe.directory | grep -qxF "$dir" \
        || sudo -u dev -H git config --global --add safe.directory "$dir"
}
