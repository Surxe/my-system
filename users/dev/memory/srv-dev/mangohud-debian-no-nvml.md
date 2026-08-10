---
name: mangohud-debian-no-nvml
description: "Debian's mangohud package is built without NVML, so NVIDIA GPU load shows 0% (esp. on Wayland)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2c68a98b-c60f-49e8-93a7-215cb8a5727a
  modified: 2026-08-02T15:36:31.318Z
---

Debian Trixie's `mangohud` package (0.7.2-2) is compiled **with XNVCtrl but WITHOUT NVML**. On NVIDIA, GPU load/temp/clocks come from NVML; without it MangoHud falls back to XNVCtrl, which only works on X11 and silently fails on Wayland → GPU usage stuck at **0%** (FPS/CPU/temps still work).

Confirmed via: `strings /usr/lib/x86_64-linux-gnu/mangohud/libMangoHud.so | grep -i nvml` returns nothing on the Debian build; the fixed build shows `nvmlInit_v2`, `nvmlDeviceGetUtilizationRates`, etc.

**Fix (used 2026-08-02 on ethan's RTX 5070 / Wayland / native .deb Steam):** install upstream MangoHud from GitHub release (has NVML). Flatpak MangoHud (`org.freedesktop.Platform.VulkanLayer.MangoHud`) has NVML but only injects into Flatpak apps, not native Steam.
1. `sudo apt-get remove mangohud` (remove the no-NVML build first, else its Vulkan layer JSON in /usr shadows the new one)
2. Download `MangoHud-<ver>.tar.gz` from github.com/flightlessmango/MangoHud/releases, extract, `./mangohud-setup.sh install` (installs to `/usr/lib/mangohud/lib64` + `/usr/bin/mangohud`, needs sudo, includes 32-bit)
3. Verify: `strings /usr/lib/mangohud/lib64/libMangoHud.so | grep -i nvml`

Manual upstream install = no auto-update. Re-running `apt install mangohud` overwrites it and reintroduces the bug. Machine has no sudo for the `dev` account; installs run as user `ethan` (uid 1000, the graphical/gaming user).
