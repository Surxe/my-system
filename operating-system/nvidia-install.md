# NVIDIA driver install method

How the NVIDIA driver on this workstation is actually installed and held in
place. Card and policy live in [../hardware/gpu.md](../hardware/gpu.md); this
file documents the mechanism.

Everything below was verified against the live system (driver `595.71.05`,
RTX 5070, kernel `6.12.101+deb13-amd64`).

## Summary

- **Open kernel module** (not the fully proprietary module), DKMS-built per
  kernel.
- Installed from **NVIDIA's official CUDA repository**, not Debian's `non-free`.
- Held at `595.71.05` by an **apt pin** (priority 1000), even though the repo
  offers newer (610.x) releases.
- Firmware comes from **Debian backports**.

## Package source: NVIDIA CUDA repo

The driver packages come from NVIDIA's CUDA repository, not Debian's own
`non-free` (which only carries the older 550.x series here).

- Source list: `/etc/apt/sources.list.d/cuda-debian13-x86_64.list`

  ```
  deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/ /
  ```

- Keyring: provided by the `cuda-keyring` package (installs
  `/usr/share/keyrings/cuda-archive-keyring.gpg`).

Confirm the installed driver resolves to this repo:

```
apt-cache policy nvidia-driver
```

The installed line (marked `***`) points at
`developer.download.nvidia.com/compute/cuda/repos/debian13`.

## Kernel module: open, DKMS-built

This is the **NVIDIA open kernel module**, not the legacy fully-proprietary one.
The userspace libraries are still proprietary; only the kernel module is open
(`Dual MIT/GPL`).

- Relevant packages: `nvidia-open`, `nvidia-kernel-open-dkms`,
  `nvidia-kernel-support`.
- The module is built locally via **DKMS** for each installed kernel, so it
  rebuilds automatically on kernel updates.

Verify (needs the module tools, so run under `sudo`):

```
sudo dkms status nvidia
cat /proc/driver/nvidia/version   # says "Open Kernel Module"
sudo modinfo nvidia | grep -iE '^(version|license)'   # license: Dual MIT/GPL
```

## Version pin: held at 595.71.05

The driver is pinned so `apt upgrade` will **not** move it to a newer release
(the repo currently also offers 610.x). This is an apt-preferences pin, **not**
an `apt-mark hold` (`apt-mark showhold` is empty).

- Pin file: `/etc/apt/preferences.d/nvidia-driver-pin`
- Shipped by the package: `nvidia-driver-pinning-595.71.05`
- Each stanza pins `version 595.71.05-*` at `Pin-Priority: 1000`, e.g.:

  ```
  Package: cuda-drivers* src:nvidia-open:any
  Pin: version 595.71.05-*
  Pin-Priority: 1000
  ```

Because the installed 595.71.05 has priority 1000 and the newer 610.x candidate
only has the default 500, apt keeps 595.71.05 as the winner.

**To intentionally move off 595** you would remove/replace the
`nvidia-driver-pinning-595.71.05` package (or its pin file) — but see the
"avoid unnecessary driver changes" warning in
[../hardware/gpu.md](../hardware/gpu.md) first.

## Firmware: from backports

The GSP/graphics firmware comes from **trixie-backports**, not stable:

- Package: `firmware-nvidia-graphics` (installed `~bpo13+1`, from
  `trixie-backports/non-free-firmware`).

```
apt-cache policy firmware-nvidia-graphics
```

## See also

- Card + policy: [../hardware/gpu.md](../hardware/gpu.md)
- Gaming-side notes: [../gaming/nvidia.md](../gaming/nvidia.md)
- Wayland compatibility: [wayland.md](wayland.md)
- NVIDIA/Vulkan history: [../troubleshooting/solved-issues.md](../troubleshooting/solved-issues.md)
