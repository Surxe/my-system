# Known issues (currently open)

Standing cautions rather than active bugs — most historical issues are resolved
([solved-issues.md](solved-issues.md)).

## Wayland-first

Wayland is an intentional choice ([../operating-system/wayland.md](../operating-system/wayland.md)).
Do **not** switch to X11 as a first-resort fix — treat it as a last resort with
explicit justification.

## NVIDIA driver stability

Avoid unnecessary NVIDIA driver changes; the current `595.71.05` works for both
desktop and gaming ([../hardware/gpu.md](../hardware/gpu.md)).

## God of War (Steam / Proton) — lower 1% lows vs Windows

**Status:** Won't-fix / inherent overhead. Not a misconfiguration.

On the same hardware, God of War posts noticeably worse **1% lows on Linux than
Windows** (~100fps vs ~130fps) while **average (~150) and max (~200) are at
parity**. This is the D3D12→Vulkan translation floor from **VKD3D-Proton**, which
Windows (native DX12) does not pay. It is not tunable away from launch options.

Tested and ruled out:

- `PROTON_ENABLE_WAYLAND=1` on vs off — no measurable difference (keep it **on**;
  native Wayland benefits, no perf cost).
- Proton Experimental → **GE-Proton11-3** — no measurable difference.
- Letting Steam's Vulkan shader pre-cache process; `__GL_SHADER_DISK_CACHE` /
  `__GL_SHADER_DISK_CACHE_SIZE` launch vars — no measurable difference (those
  vars aren't reliably inherited by Steam's separate `fossilize_replay` anyway).
- Shader cache confirmed **healthy** on ext4:
  `~/.steam/debian-installation/steamapps/shadercache/1593500/fozpipelinesv6`
  (~8.1 GB), so in-game on-the-fly compilation is not the cause.

Notes:

- The "Processing Vulkan shaders" popup at launch is **Proton/Linux-only**
  (Fossilize); Windows caches shaders transparently in-driver, so its absence on
  Windows is expected, not a symptom.
- Settled launch options:
  `PROTON_ENABLE_WAYLAND=1 gamemoderun mangohud %command%`.

_No other open issues recorded._
