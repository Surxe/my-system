# Handy commands

> **TODO — grow this over time.**
> Diagnostic / recovery commands worth remembering for this machine.

Starting points (all read-only; also bundled in
[../scripts/inventory.sh](../scripts/inventory.sh)):

```bash
uname -r                     # kernel version
nvidia-smi                   # GPU + driver
lsblk -f                     # block devices + filesystems
mount | column -t            # active mounts
getent group developers      # shared-dev group membership
systemctl --failed           # failed units
```
