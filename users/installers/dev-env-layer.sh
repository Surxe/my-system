#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"

# --- dev-env-layer: deploy the shared dev-environment layer from dev-env repo
#     (skills pr/merged/brainstorm, cc launcher, statusline, universal memories).
#     The dev-env/install.sh handles all the logic; this is just the hookpoint. ---
DEV_ENV_REPO="${REPO_ROOT}/../dev-env"
[ -d "$DEV_ENV_REPO" ] || { say "dev-env-layer: no dev-env repo at $DEV_ENV_REPO — skipping"; return 0; }

# Refresh the shared dev-env clone first (as dev, to keep it dev-owned), so this
# box deploys the latest shared layer rather than a stale clone. Warn, don't fail.
if [ "$ME" = dev ]; then
    git -C "$DEV_ENV_REPO" pull --ff-only || warn "could not update dev-env clone"
else
    sudo -u dev git -C "$DEV_ENV_REPO" pull --ff-only || warn "could not update dev-env clone"
fi

say "== deploy shared dev-env layer (-> ~dev/.agents + ~/.claude symlinks / ~dev/.bashrc.d / ~dev/.dsh) =="
if [ "$ME" = dev ]; then
    "$DEV_ENV_REPO/install.sh" --host workstation
else
    sudo -u dev "$DEV_ENV_REPO/install.sh" --host workstation
fi
say "dev-tier: shared layer installed"
