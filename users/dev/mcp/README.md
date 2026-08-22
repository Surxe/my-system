# dev's Claude Code MCP servers (inventory)

One JSON file per stdio MCP server that should be registered for the `dev` user's
Claude Code. The `dev-mcp` installer (`users/installers/dev-mcp.sh`) reads every
`*.json` here and reconciles it into dev's live Claude config, so a fresh machine
gets all declared servers from a single `install.sh` run instead of hand-run
`claude mcp add` calls.

## Format

```jsonc
{
  "name": "clip-viewer",              // MCP server name (as it appears in `claude mcp list`)
  "repo": "clip-db",                  // repo dir under /srv/dev/repos that owns the server
  "command": ".venv/bin/python",      // launch command, RELATIVE to the repo root
  "args": ["clip-viewer-mcp/server.py"], // args; path-like entries are made absolute, flags (-x) pass through
  "scope": "user"                     // claude mcp scope: user (default) | local | project
}
```

Paths are stored repo-relative and expanded to absolute against
`/srv/dev/repos/<repo>` at install time. That keeps the inventory portable (a new
PC following the same repos layout just works) while satisfying `user` scope,
which is cwd-independent and therefore needs absolute commands.

## Why user scope

`user` scope makes the server available in every project dev opens, regardless of
the directory Claude was launched from. `local`/`project` scope only load when
Claude starts inside the owning repo — so a prompt driven from a parent dir (e.g.
`/srv/dev`) would not see the tools. See `dev-mcp.sh` for the reconcile logic.

## Idempotency

`claude mcp add` errors if the server already exists, so the installer does
`claude mcp remove` then `claude mcp add` per entry. That is idempotent and also
redeploys definition changes (edited command/args/scope).
