#!/usr/bin/env bash
# ------------------------------------------------------------------
# 01-host-prepare-hugepages.sh
#
# Reserves 1Gi HugePages INSIDE THE KVM GUEST for the SD-Core UPF pod.
#
# This script runs INSIDE the guest VM (Ubuntu 24.04), not on the
# KVM host. It modifies the guest kernel command line so that 4Gi of
# 1G pages are available to Kubernetes as a schedulable resource.
#
# Historical note: on the earlier Rocky Linux project, we used grubby
# (BLS-aware). Ubuntu uses /etc/default/grub + update-grub, which is
# the same file that BLS reads on Debian-family systems, so it works.
#
# See docs/04-troubleshooting.md #1 for the Rocky BLS gotcha.
# ------------------------------------------------------------------

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Must be run as root (or via sudo)."
  exit 1
fi

HUGEPAGES="${HUGEPAGES:-4}"
HUGE_SIZE="${HUGE_SIZE:-1G}"

echo "[+] Configuring ${HUGEPAGES} x ${HUGE_SIZE} HugePages"
echo "[+] intel_iommu=on iommu=pt also being set (for any future VFIO work)"

GRUB_FILE="/etc/default/grub"
GRUB_ARGS="intel_iommu=on iommu=pt default_hugepagesz=${HUGE_SIZE} hugepagesz=${HUGE_SIZE} hugepages=${HUGEPAGES}"

if grep -q "hugepagesz=${HUGE_SIZE}" "${GRUB_FILE}"; then
  echo "[=] HugePages already configured in ${GRUB_FILE}, skipping edit"
else
  cp "${GRUB_FILE}" "${GRUB_FILE}.bak.$(date +%s)"
  sed -i "s|^GRUB_CMDLINE_LINUX=\"\(.*\)\"|GRUB_CMDLINE_LINUX=\"\1 ${GRUB_ARGS}\"|" "${GRUB_FILE}"
  echo "[+] Updated ${GRUB_FILE}"
fi

echo "[+] Running update-grub"
update-grub

echo
echo "[+] Reboot required for hugepages to take effect."
echo "    After reboot, verify with:"
echo "        grep -i huge /proc/meminfo"
echo "        kubectl describe node \$(hostname -s) | grep hugepages"
echo
echo "    Expected:"
echo "        HugePages_Total:       ${HUGEPAGES}"
echo "        Hugepagesize:    1048576 kB"
echo "        hugepages-1Gi:    ${HUGEPAGES}Gi"