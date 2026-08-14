---
name: no-email-in-repos
description: "never commit email addresses to any repo; they live in Ethan's config set manually"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0f52b1f4-f691-44ff-979b-3c0096617093
  modified: 2026-08-14T05:21:24.204Z
---

Email addresses are never checked in to any repository. They should always live
in Ethan's config, set manually by him.

**Why:** Keeping emails out of the git tree avoids leaking them via public repos
and keeps them as machine-local config rather than shared source.

**How to apply:** Don't hardcode or commit any email address (git user.email,
config files, scripts, docs). If a repo needs to reference where an email is
configured, document its *location* in my-system rather than the value itself.
Related: [[user-specific-via-my-system]], [[my-system-generated-files]].
