#!/usr/bin/env bash
#
# generate-repo-descriptions.sh
#
# Produce the "repo descriptions" SECTION of the assembled CLAUDE.md. It pairs
# each repo directory under /srv/dev/repos with its GitHub *description*.
#
# This does NOT write CLAUDE.md directly — it writes a section file under
# sections/, which build-claude-md.sh embeds into the CLAUDE.md blueprint.
#
# The GitHub description is repo metadata (the one-liner on the repo page), not
# a file in the git tree, so it cannot be read from a local clone — it is
# fetched from the GitHub API. Public repos need no auth; private repos require
# dev's PAT, which is read at runtime from the git credential helper
# (~/.git-credentials). The token is NEVER hardcoded or printed here.
#
# Regenerate whenever repos are added/removed or descriptions change (normally
# invoked for you by build-claude-md.sh):
#   /srv/dev/repos/my-system/users/dev/scripts/generate-repo-descriptions.sh

set -euo pipefail

REPOS_DIR="${REPOS_DIR:-/srv/dev/repos}"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_FILE="${OUT_FILE:-$REPO_ROOT/sections/repo-descriptions.md}"
API="https://api.github.com"

# --- description cache -----------------------------------------------------
# The GitHub description rarely changes, so we avoid an API round-trip per repo
# by caching each slug's description keyed on the local HEAD SHA. On a run we
# read the SHA locally (free) and only call the API when the SHA changed since
# we last cached it. Because a description CAN change on GitHub without a new
# commit, a cache entry older than CACHE_TTL_DAYS is refreshed regardless, and
# --force bypasses the cache entirely. Cache is regenerable derived state, kept
# out of git (see .gitignore) — a fresh checkout just repopulates it.
CACHE_FILE="${CACHE_FILE:-$REPO_ROOT/.cache/repo-descriptions.json}"
CACHE_TTL_DAYS="${CACHE_TTL_DAYS:-14}"

FORCE=0
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    -h|--help)
      echo "usage: $(basename "$0") [--force]"
      echo "  --force  ignore the description cache and re-fetch every repo"
      exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# --- token -----------------------------------------------------------------
# Pull the PAT from the git credential helper once. Sending it on every call
# also lifts us off the low unauthenticated API rate limit. Empty if none.
TOKEN="$(printf 'protocol=https\nhost=github.com\n\n' \
  | git credential fill 2>/dev/null \
  | sed -n 's/^password=//p' || true)"

# Build curl auth args as an array so the header survives word-splitting.
# (A bare ${TOKEN:+-H "..."} re-splits after expansion and mangles the header.)
AUTH_ARGS=()
[ -n "$TOKEN" ] && AUTH_ARGS=(-H "Authorization: Bearer $TOKEN")

# --- helpers ---------------------------------------------------------------

# Strip embedded credentials from a remote URL so a tokenized remote
# (e.g. https://<PAT>@github.com/owner/repo.git) never lands in the generated
# output. Removes the "userinfo@" between the scheme and the host; leaves
# scp-style ssh remotes (git@github.com:owner/repo) untouched, since there the
# "git@" is the SSH user, not a secret. Applied to EVERY remote URL before it
# is classified or printed — the leak this guards against is a tokenized remote
# being mis-classified as a non-GitHub remote and printed verbatim.
strip_url_creds() {
  local url="$1" scheme rest hostpart
  # Only http(s) — that is where a token/password embeds. SSH userinfo ("git@")
  # is just a username, is not a secret, and slug_from_url keys off it.
  case "$url" in
    http://*|https://*)
      scheme="${url%%://*}://"
      rest="${url#"$scheme"}"
      hostpart="${rest%%/*}"          # authority component, before the first '/'
      [ "${hostpart#*@}" != "$hostpart" ] && rest="${rest#*@}"  # drop userinfo@
      url="$scheme$rest"
      ;;
  esac
  printf '%s' "$url"
}

# origin URL -> "owner/repo", or non-zero exit if not a GitHub remote.
slug_from_url() {
  local url="$1"
  case "$url" in
    git@github.com:*)       url="${url#git@github.com:}" ;;
    ssh://git@github.com/*) url="${url#ssh://git@github.com/}" ;;
    https://github.com/*)   url="${url#https://github.com/}" ;;
    http://github.com/*)    url="${url#http://github.com/}" ;;
    *) return 1 ;;
  esac
  printf '%s' "${url%.git}"
}

# owner/repo -> description text, or a parenthetical status marker.
#
# Sets two globals rather than only printing, so the caller can tell a
# definitive answer (safe to cache) from a transient failure (reuse the old
# cached value instead of poisoning the cache with an error):
#   FETCH_TEXT  the description or status marker
#   FETCH_OK    1 = definitive (200/404), 0 = transient (network/auth/5xx)
fetch_description() {
  local slug="$1" resp http body desc
  FETCH_OK=0
  resp="$(curl -sS -w $'\n%{http_code}' \
      "${AUTH_ARGS[@]}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$API/repos/$slug" 2>/dev/null)" || { FETCH_TEXT='(error contacting GitHub)'; return; }
  http="${resp##*$'\n'}"
  body="${resp%$'\n'*}"
  case "$http" in
    200)
      desc="$(printf '%s' "$body" | jq -r '.description // ""')"
      [ -n "$desc" ] && FETCH_TEXT="$desc" || FETCH_TEXT='(no description set)'
      FETCH_OK=1
      ;;
    404)     FETCH_TEXT='(not found or dev lacks access)'; FETCH_OK=1 ;;
    401|403) FETCH_TEXT='(unauthorized — check dev PAT)' ;;
    *)       FETCH_TEXT="(HTTP $http)" ;;
  esac
}

# --- build -----------------------------------------------------------------
tracked=""   # lines for GitHub-backed repos
local_only="" # lines for repos with no GitHub remote

# Load the existing cache (best effort — a missing or corrupt file is just a
# cold cache). NEW_CACHE is rebuilt from scratch so slugs for removed repos
# age out automatically.
OLD_CACHE='{}'
if [ -f "$CACHE_FILE" ]; then
  OLD_CACHE="$(jq -e . "$CACHE_FILE" 2>/dev/null || echo '{}')"
fi
NEW_CACHE='{}'
NOW="$(date +%s)"
TTL_SECS=$(( CACHE_TTL_DAYS * 86400 ))
hits=0 misses=0

for dir in "$REPOS_DIR"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  url="$(strip_url_creds "$url")"   # never let an embedded PAT reach the output

  path="$REPOS_DIR/$name"

  if [ -z "$url" ]; then
    local_only+="- **$name** — \`$path\` — local-only (no GitHub remote)"$'\n'
    continue
  fi

  if ! slug="$(slug_from_url "$url")"; then
    tracked+="- **$name** — \`$path\` (\`$url\`) — (non-GitHub remote)"$'\n'
    continue
  fi

  # Local HEAD SHA is the cache key (read locally, no API cost). Empty for a
  # repo with no commits — then we can't SHA-gate, so we always fetch.
  sha="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"

  # Pull any prior cache entry for this slug.
  c_sha="$(printf '%s' "$OLD_CACHE"  | jq -r --arg s "$slug" '.[$s].sha         // empty')"
  c_desc="$(printf '%s' "$OLD_CACHE" | jq -r --arg s "$slug" '.[$s].description // empty')"
  c_ts="$(printf '%s' "$OLD_CACHE"   | jq -r --arg s "$slug" '.[$s].fetched     // 0')"

  # Decide the description and exactly what to persist. store_sha empty means
  # "persist nothing" (SHA-less repo or a transient failure with no fallback),
  # so that repo is retried on the next run instead of caching junk.
  store_sha="" store_desc="" store_ts=""

  # A cache hit needs: not --force, a non-empty local SHA that matches the
  # cached SHA, a cached description, and an entry younger than the TTL.
  if [ "$FORCE" -eq 0 ] && [ -n "$sha" ] && [ "$sha" = "$c_sha" ] \
       && [ -n "$c_desc" ] && [ $(( NOW - c_ts )) -lt "$TTL_SECS" ]; then
    desc="$c_desc"
    # Re-persist unchanged, preserving the ORIGINAL fetch time so the TTL keeps
    # counting from the last real fetch rather than resetting on every hit.
    store_sha="$sha" store_desc="$c_desc" store_ts="$c_ts"
    hits=$(( hits + 1 ))
  else
    misses=$(( misses + 1 ))
    fetch_description "$slug"   # sets FETCH_TEXT / FETCH_OK
    if [ "$FETCH_OK" -eq 1 ]; then
      # Definitive answer — cache it against the current SHA, timestamped now.
      desc="$FETCH_TEXT"
      [ -n "$sha" ] && { store_sha="$sha" store_desc="$desc" store_ts="$NOW"; }
    elif [ -n "$c_desc" ]; then
      # Transient failure — show the stale value and keep the OLD entry verbatim
      # (old SHA + old time) so next run still sees a mismatch and retries.
      desc="$c_desc"
      [ -n "$c_sha" ] && { store_sha="$c_sha" store_desc="$c_desc" store_ts="$c_ts"; }
    else
      desc="$FETCH_TEXT"        # transient failure, nothing cached — show marker
    fi
  fi

  tracked+="- **$name** — \`$path\` (\`$slug\`) — $desc"$'\n'

  if [ -n "$store_sha" ]; then
    NEW_CACHE="$(printf '%s' "$NEW_CACHE" | jq \
      --arg s "$slug" --arg sha "$store_sha" --arg desc "$store_desc" --argjson ts "$store_ts" \
      '.[$s] = {sha: $sha, description: $desc, fetched: $ts}')"
  fi
done

# --- write (atomically) ----------------------------------------------------
mkdir -p "$(dirname "$OUT_FILE")"
tmp="$(mktemp "$OUT_FILE.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

{
  echo "<!-- SECTION: repo-descriptions -->"
  echo "<!-- AUTO-GENERATED by scripts/generate-repo-descriptions.sh — do not edit by hand. -->"
  echo
  echo "## Ethan's repositories live under \`$REPOS_DIR\`"
  echo
  echo "**All of Ethan's projects/repos are directories under \`$REPOS_DIR\`.**"
  echo "When Ethan names a repository — or just says \"repo\", \"the repo\", \"my"
  echo "project\", etc. — resolve it to a directory in the list below and work there."
  echo "Do this by default:"
  echo
  echo "- **Always look here first.** Before saying a repo can't be found, or asking"
  echo "  where it is, check \`$REPOS_DIR\` — e.g. \`ls $REPOS_DIR\` or"
  echo "  \`$REPOS_DIR/<name>\`. The name Ethan says is the directory name."
  echo "- Match loosely: names may differ in case/hyphenation from what Ethan types."
  echo "- Each entry below gives the directory's **absolute path** — cd/read there"
  echo "  directly; don't re-discover it."
  echo "- The description is the repo's GitHub metadata (not the README), for"
  echo "  recognizing which project is which."
  echo
  echo "### GitHub-tracked"
  echo
  printf '%s' "$tracked"
  if [ -n "$local_only" ]; then
    echo
    echo "### Local-only (no GitHub remote)"
    echo
    printf '%s' "$local_only"
  fi
} > "$tmp"

chmod 664 "$tmp"   # mktemp defaults to 0600; restore group read for the developers group
mv "$tmp" "$OUT_FILE"
trap - EXIT
echo "Wrote $OUT_FILE"

# --- persist the cache (atomically) ----------------------------------------
mkdir -p "$(dirname "$CACHE_FILE")"
ctmp="$(mktemp "$CACHE_FILE.XXXXXX")"
trap 'rm -f "$ctmp"' EXIT
printf '%s\n' "$NEW_CACHE" > "$ctmp"
chmod 664 "$ctmp"
mv "$ctmp" "$CACHE_FILE"
trap - EXIT
echo "Cache: $hits hit(s), $misses fetch(es) -> $CACHE_FILE"
