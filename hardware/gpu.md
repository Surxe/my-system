# GPU

**NVIDIA RTX 5070**

- Driver: proprietary NVIDIA `595.71.05`.
- Must remain **Wayland compatible** (see [../operating-system/wayland.md](../operating-system/wayland.md)).
- The card is detected correctly and Vulkan works — see
  [../troubleshooting/solved-issues.md](../troubleshooting/solved-issues.md) for
  the NVIDIA/Vulkan history.

**Avoid unnecessary driver changes.** The current driver works; changing it risks
regressing Wayland/Vulkan.

Gaming-side driver notes: [../gaming/nvidia.md](../gaming/nvidia.md).
