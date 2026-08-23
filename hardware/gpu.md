# GPU

**NVIDIA RTX 5070**

- Driver: NVIDIA `595.71.05`, **open kernel module** (userspace libs are still
  proprietary; the kernel module is `Dual MIT/GPL`). Installed from NVIDIA's
  CUDA repo and pinned at this version — see
  [../operating-system/nvidia-install.md](../operating-system/nvidia-install.md)
  for the full install method.
- Must remain **Wayland compatible** (see [../operating-system/wayland.md](../operating-system/wayland.md)).
- The card is detected correctly and Vulkan works — see
  [../troubleshooting/solved-issues.md](../troubleshooting/solved-issues.md) for
  the NVIDIA/Vulkan history.

**Avoid unnecessary driver changes.** The current driver works; changing it risks
regressing Wayland/Vulkan.

Gaming-side driver notes: [../gaming/nvidia.md](../gaming/nvidia.md).
