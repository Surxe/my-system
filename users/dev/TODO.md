# TODO

- [ ] **Auto-rebuild via git hook.** Wire `build-claude-md.sh` into a hook so
      `CLAUDE.md` stays fresh without a manual run. Open questions to settle first:
  - Which hook / where: a repo-local `post-commit` here is too narrow (repos are
    added/removed elsewhere). More useful is a hook (or a small timer/cron) that
    reruns the build when the set of repos under `/srv/dev/repos` changes, or on a
    schedule, since GitHub descriptions can change with no local commit.
  - Network dependency: the build hits the GitHub API, so a commit-time hook would
    add latency and fail offline — probably want it non-blocking / best-effort.
  - Decide before implementing (deliberately deferred for now).
