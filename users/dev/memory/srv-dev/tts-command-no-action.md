---
name: tts-command-no-action
description: "`!tts` shell calls (say/stop/on/off/status) are Ethan driving TTS — never respond or act"
metadata:
  node_type: memory
  type: feedback
---

`!tts ...` calls (say, stop, on, off, status) are Ethan controlling text-to-speech playback, not a request. Stay silent — no acknowledgment, no action, no tokens. Related: [[todo-command-no-action]].
