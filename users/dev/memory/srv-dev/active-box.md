---
name: active-box
description: You are running on the workstation — hostname ethan-debian, the my-system box
metadata:
  type: reference
---

**Active box: workstation** — hostname `ethan-debian`.

This is the `my-system` box (Debian dual-boot desktop). Because box-local
memories only deploy to their own machine, the mere presence of this note in
the `my-system` layer confirms the box: if you are reading it, you are on the
workstation. The home-server box carries its own parallel `active-box` note
instead.

Use this to resolve any box-conditional guidance directly, without inferring
the box from which repos/paths exist or running `hostname` yourself. See
[[box-repos]] for the three-repo layout and [[edit-in-repo]] for the deploy
model.

Static by design: if the hostname ever changes, edit this note and rerun
`/srv/dev/repos/my-system/users/install.sh` — it does not auto-refresh.
