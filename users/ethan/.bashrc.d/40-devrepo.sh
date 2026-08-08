# --- accept any pending Surxe-dev collaborator invitations (runs AS dev) ---
devaccept() {
    sudo -u dev -H bash -c '
        set -euo pipefail
        export GIT_TERMINAL_PROMPT=0
        tok=$(printf "protocol=https\nhost=github.com\n\n" \
              | git credential fill 2>/dev/null | sed -n "s/^password=//p")
        [ -n "$tok" ] || { echo "devaccept: no dev github token in credential store" >&2; exit 1; }
        ids=$(GH_TOKEN="$tok" gh api /user/repository_invitations --jq ".[].id" 2>/dev/null || true)
        for id in $ids; do
            GH_TOKEN="$tok" gh api -X PATCH "/user/repository_invitations/$id" >/dev/null \
                && echo "devaccept: accepted invitation $id"
        done
    '
}

# --- unified repo helper: create-or-clone under /srv/dev/repos, then work as dev ---
#   devrepo new   <reponame> [--private|--public]   (default: public)
#   devrepo clone <profile>/<reponame>              (must already exist on GitHub)
devrepo() {
    local mode="${1:-}" dest reponame slug url
    shift 2>/dev/null || true

    case "$mode" in
        new)
            reponame="${1:-}"
            dest="/srv/dev/repos/$reponame"
            if [ -z "$reponame" ] || [[ "$reponame" == */* ]]; then
                echo "usage: devrepo new <reponame> [--private|--public]  (default: public)" >&2; return 1
            fi
            [ -e "$dest" ] && { echo "already exists: $dest" >&2; return 1; }
            url="$(sudo -u ethan -H /usr/local/sbin/devscaffold "$reponame" "${2:-}")" || return 1
            git init -b master "$dest"              || return 1
            git -C "$dest" remote add origin "$url" || return 1
            ;;
        clone)
            slug="${1%.git}"
            reponame="${slug##*/}"
            dest="/srv/dev/repos/$reponame"
            url="https://github.com/${slug}.git"
            if [ -z "$slug" ] || [ "$slug" = "$reponame" ]; then
                echo "usage: devrepo clone <profile>/<reponame>" >&2; return 1
            fi
            [ -e "$dest" ] && { echo "already exists: $dest" >&2; return 1; }
            git clone "$url" "$dest" || return 1
            ;;
        *)
            echo "usage: devrepo <new|clone> ..." >&2; return 1
            ;;
    esac

    # shared tail: perms + both safe-dirs + accept invite + jump in as dev
    devperms "$dest"      || return 1
    devsafe_ethan "$dest" || return 1
    devsafe_dev "$dest"   || return 1
    devaccept || echo "warning: could not auto-accept invitations — accept manually" >&2
    cd "$dest" || return 1
    devsh
}
