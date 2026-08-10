---
name: bt-headphone-x11-relink
description: "BT headphone \"X11\" fails to connect on Debian after being used on Windows — stale link key, fix is remove + re-pair"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5b8e67db-c51c-43a4-915e-f32f0c3fe99a
  modified: 2026-08-04T22:27:36.698Z
---

Ethan's Bluetooth headphone reports itself as **"X11"** (MAC `8E:6B:51:C9:A4:F7`, single-host device). It connects fine on his Windows machine but on the Debian workstation (`ethan-debian`) connect attempts fail with `org.bluez.Error.Failed br-connection-page-timeout`.

**Cause:** re-pairing the headphone to Windows resets its side of the link key; Debian keeps the old bond, so the headphone ignores Debian's reconnect page (visible in an inquiry scan but refuses the page). NOT an audio-stack problem — PipeWire/pipewire-pulse/WirePlumber/BlueZ/`libspa-0.2-bluetooth` are all installed and healthy.

**Fix (headphone in pairing mode):**
```
bluetoothctl remove 8E:6B:51:C9:A4:F7
bluetoothctl pair 8E:6B:51:C9:A4:F7
bluetoothctl trust 8E:6B:51:C9:A4:F7
bluetoothctl connect 8E:6B:51:C9:A4:F7
```
Likely recurs each time the headphone is switched back to Windows and returned.

**Note on env:** the `dev` account (uid 1001, what Claude runs as) cannot query PipeWire — the desktop session runs as user `ethan` (uid 1000) and its `/run/user/1000` socket is 0700. BlueZ works from `dev` because it's on the system bus; `pactl`/`wpctl` do not. Sink selection / A2DP-vs-HFP profile must be done by Ethan in KDE System Settings → Audio.
