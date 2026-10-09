# --- the git safe.directory entries a repo needs: the repo + its submodules ---
# safe.directory is per path, not recursive: a submodule's worktree is checked on
# its own, and git refuses it ("dubious ownership") when it is owned by the other
# user. Submodule paths come from every .gitmodules in the repo (nested ones too,
# once initialised); paths not checked out yet are listed anyway.
devsafe_paths() {
    local dir; dir="$(readlink -f -- "${1:-$PWD}")" || return 1
    printf '%s\n' "$dir"
    local modules sub
    while IFS= read -r modules; do
        sub="$(dirname -- "$modules")"
        git config -f "$modules" --get-regexp '^submodule\..*\.path$' 2>/dev/null \
            | while read -r _ path; do printf '%s/%s\n' "$sub" "$path"; done
    done < <(find "$dir" -name node_modules -prune -o -name .gitmodules -type f -print 2>/dev/null)
}

# --- mark a repo (and its submodules) as git safe.directory for THIS user (idempotent) ---
devsafe_ethan() {
    local path paths; paths="$(devsafe_paths "${1:-$PWD}")" || return 1
    while IFS= read -r path; do
        git config --global --get-all safe.directory | grep -qxF "$path" \
            || git config --global --add safe.directory "$path"
    done <<< "$paths"
}

# --- mark a repo (and its submodules) as git safe.directory for the DEV user (idempotent) ---
# Runs git as dev via sudo -H so it writes /home/dev/.gitconfig, not ethan's.
devsafe_dev() {
    local path paths; paths="$(devsafe_paths "${1:-$PWD}")" || return 1
    while IFS= read -r path; do
        sudo -u dev -H git config --global --get-all safe.directory | grep -qxF "$path" \
            || sudo -u dev -H git config --global --add safe.directory "$path"
    done <<< "$paths"
}
