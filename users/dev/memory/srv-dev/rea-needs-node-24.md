---
name: rea-needs-node-24
description: REA CLI only runs under nvm Node 24 -- `nvm use 24` before any `rea` command
metadata:
  type: reference
---

`rea` is npm-linked under nvm Node 24.22.1; the nvm default stays 22. Run
`source ~/.nvm/nvm.sh && nvm use 24` before any `rea` command.
