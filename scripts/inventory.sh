#!/usr/bin/env bash
#
# inventory.sh — read-only system snapshot for the system-context repo.
#
# Prints hardware / OS / storage / package facts to stdout to help populate the
# "TODO — not yet documented" scaffolds. Makes NO changes and touches NO secrets.
# Some sections need root (e.g. dmidecode); they degrade gracefully otherwise.
#
# Usage:
#   scripts/inventory.sh          # normal detail
#   sudo scripts/inventory.sh     # fuller hardware detail (dmidecode)

set -u

section() { printf '\n=== %s ===\n' "$1"; }

# Run a command only if it exists; otherwise note it's missing.
have() { command -v "$1" >/dev/null 2>&1; }
run()  { if have "$1"; then "$@"; else echo "(skipped: '$1' not installed)"; fi; }

is_root() { [ "$(id -u)" -eq 0 ]; }

printf 'system-context inventory — read-only snapshot\n'
printf 'host: %s\n' "$(uname -n)"

section "OS / kernel"
run uname -a
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf 'distro: %s\n' "${PRETTY_NAME:-unknown}"
fi
printf 'session type: %s\n' "${XDG_SESSION_TYPE:-unknown}"
printf 'desktop: %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"

section "CPU"
run lscpu

section "Memory (summary)"
run free -h

section "GPU"
run lspci -nnk | grep -iA3 -e vga -e '3d' -e display || true
section "NVIDIA driver"
run nvidia-smi

section "Motherboard / memory (dmidecode — needs root)"
if is_root && have dmidecode; then
    dmidecode -t baseboard -t memory
else
    echo "(skipped: re-run with sudo and dmidecode installed for board/RAM detail)"
fi

section "Block devices & filesystems"
run lsblk -f

section "Mounts"
run findmnt --real 2>/dev/null || mount | grep -Ev '^(proc|sys|tmpfs|cgroup|devpts|mqueue|hugetlbfs)'

section "Disk usage"
run df -h -x tmpfs -x devtmpfs

section "USB peripherals"
run lsusb

section "Users & groups (developers)"
getent group developers || echo "(no 'developers' group)"
printf 'current user: %s (uid %s)\n' "$(id -un)" "$(id -u)"

section "Enabled systemd units"
run systemctl list-unit-files --state=enabled --no-pager

section "Manually-installed apt packages"
run apt-mark showmanual

section "Flatpaks"
run flatpak list --app

printf '\nDone. This snapshot changed nothing.\n'
