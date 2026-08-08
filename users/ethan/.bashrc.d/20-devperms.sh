# --- fix permissions on a repo (shared ethan <-> dev) ---
devperms() {
    local dir; dir="$(readlink -f -- "${1:-$PWD}")" || return 1
    sudo /usr/local/sbin/devperms "$dir"
}
