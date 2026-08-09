# --- accept pending Surxe-dev collaborator invitations (runs AS dev) ---
#   devaccept [repo]   # if repo given, poll until that invite arrives (bounded)
devaccept() {
    sudo -u dev -H WANT_REPO="${1:-}" bash -c '
        set -euo pipefail
        export GIT_TERMINAL_PROMPT=0
        tok=$(printf "protocol=https\nhost=github.com\n\n" \
              | git credential fill 2>/dev/null | sed -n "s/^password=//p")
        [ -n "$tok" ] || { echo "devaccept: no dev github token in credential store" >&2; exit 1; }

        want="$WANT_REPO"
        start=$(date +%s)
        deadline=$(( start + 20 ))   # cap the wait at 20s

        while :; do
            invites=$(GH_TOKEN="$tok" gh api /user/repository_invitations \
                        --jq ".[] | \"\(.id)\t\(.repository.name)\"" 2>/dev/null || true)

            # accept everything visible right now
            printf "%s\n" "$invites" | while IFS=$'"'"'\t'"'"' read -r id name; do
                [ -n "$id" ] || continue
                GH_TOKEN="$tok" gh api -X PATCH "/user/repository_invitations/$id" >/dev/null \
                    && echo "devaccept: accepted invitation $id ($name)"
            done

            # done if not waiting for a specific repo, or it just showed up
            if [ -z "$want" ] || printf "%s\n" "$invites" | grep -qP "\t${want}$"; then
                [ -n "$want" ] && echo "devaccept: $want invite seen after $(( $(date +%s) - start ))s"
                break
            fi
            [ "$(date +%s)" -ge "$deadline" ] && {
                echo "devaccept: timed out after $(( $(date +%s) - start ))s waiting for $want" >&2
                exit 1
            }
            sleep 1
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
            git init -b main "$dest"                                  || return 1
            git -C "$dest" remote add origin "$url"                   || return 1
            # seed the default branch on both sides and connect them: an empty
            # initial commit gives the remote a `main` to receive, and `push -u`
            # sets local main to track origin/main. (ethan owns the repo, so the
            # admin bypass on the protection ruleset lets this direct push land.)
            git -C "$dest" commit --allow-empty -m "Initial commit"   || return 1
            GIT_TERMINAL_PROMPT=0 git -C "$dest" push -u origin main  || return 1
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
    devaccept "$reponame" || echo "warning: could not auto-accept invitations — accept manually" >&2
    cd "$dest" || return 1
    devsh
}
