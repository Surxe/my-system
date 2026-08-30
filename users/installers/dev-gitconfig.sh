#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-tier: set dev's GLOBAL git author identity in ~dev/.gitconfig ---
# Same trust model as dev-bashrc / dev's CLAUDE.md: dev's own home file, so there is
# NO review gate.
#
# WHY these values: GitHub credits a commit to an account by its AUTHOR EMAIL, which
# is independent of the account whose PAT pushed it. Authoring dev's commits under
# Surxe's GitHub noreply address routes credit to Ethan's `Surxe` account (numeric
# id 119145352), even though the push still uses the Surxe-dev PAT:
#   - Direct pushes preserve the local author -> Surxe is the PRIMARY author.
#   - Squash-merged PRs force the author to the PR-submitter account (Surxe-dev), but
#     GitHub keeps the head commit's author as a Co-authored-by trailer, so Surxe
#     gets CO-AUTHOR credit (counts on the contribution graph). Primary credit on PRs
#     would need a merge-commit policy instead of squash; not done here.
# Attribution and the actor-based merge gate are independent, so this does NOT weaken
# the gate. See development/git-workflow.md.
#
# The name stays `Surxe-dev` (transparent that automation authored the commit); only
# the email carries the credit. `+noreply` addresses are public-by-design and carry
# no private mailbox, so committing this value is allowed — see the no-email-in-repos
# memory. `git config --global` overwrites only these two keys, leaving dev's
# existing safe.directory / credential.helper entries intact. Idempotent.
DEV_GIT_NAME="Surxe-dev"
DEV_GIT_EMAIL="119145352+Surxe@users.noreply.github.com"

deploy_dev_gitconfig() {
    if [ "$ME" = dev ]; then
        git config --global user.name  "$DEV_GIT_NAME"
        git config --global user.email "$DEV_GIT_EMAIL"
    else
        sudo -u dev git config --global user.name  "$DEV_GIT_NAME"
        sudo -u dev git config --global user.email "$DEV_GIT_EMAIL"
    fi
    say "dev-tier: set dev git identity -> $DEV_GIT_NAME <$DEV_GIT_EMAIL>"
}
deploy_dev_gitconfig
