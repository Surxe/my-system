#!/usr/bin/env bash
#
# backup-check.sh — read-only Restic backup health check.
#
# Reads Restic credentials FROM THE ENVIRONMENT and never embeds or prints them.
# Makes no changes to backups (snapshots + check are read-only operations).
#
# Configure before running (values must live OUTSIDE this repo):
#   export RESTIC_REPOSITORY=...                 # e.g. b2:bucket:path
#   export RESTIC_PASSWORD_FILE=/path/to/pwfile  # (or RESTIC_PASSWORD)
#   # plus B2 credentials, e.g. B2_ACCOUNT_ID / B2_ACCOUNT_KEY
#
# See ../storage/restic.md and ../private/secrets-policy.md.

set -u

if ! command -v restic >/dev/null 2>&1; then
    echo "restic is not installed. Install it (e.g. 'apt install restic') and retry." >&2
    exit 1
fi

if [ -z "${RESTIC_REPOSITORY:-}" ]; then
    cat >&2 <<'EOF'
RESTIC_REPOSITORY is not set.

This script intentionally holds no credentials. Set them in your environment
first (keep the actual values outside this repo):

  export RESTIC_REPOSITORY=...
  export RESTIC_PASSWORD_FILE=/path/outside/this/repo   # or RESTIC_PASSWORD
  # + Backblaze B2 credentials

Then re-run: scripts/backup-check.sh
EOF
    exit 2
fi

if [ -z "${RESTIC_PASSWORD_FILE:-}" ] && [ -z "${RESTIC_PASSWORD:-}" ]; then
    echo "Neither RESTIC_PASSWORD_FILE nor RESTIC_PASSWORD is set." >&2
    exit 2
fi

echo "== restic version =="
restic version

echo
echo "== latest snapshots =="
restic snapshots --latest 10 || { echo "Failed to list snapshots." >&2; exit 3; }

# Structural integrity check (metadata only; does not re-download all data).
echo
echo "== repository check (structure only) =="
restic check || { echo "Repository check reported problems." >&2; exit 4; }

echo
echo "Backup check complete."
