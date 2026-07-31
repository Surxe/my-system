# Boot

- **Bootloader:** GRUB (manages the Windows / Debian dual-boot).
- **Secure Boot:** **disabled intentionally** — supports the proprietary NVIDIA
  driver without module-signing overhead. Don't re-enable without discussion
  (see [../decisions/rejected-options.md](../decisions/rejected-options.md)).

The OS drive holds an EFI partition alongside Windows and Debian — see
[../storage/disk-layout.md](../storage/disk-layout.md).
