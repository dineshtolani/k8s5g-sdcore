#!/usr/bin/env bash
# ------------------------------------------------------------------
# 02-vm-network-setup.sh
#
# Configures the three network interfaces inside the guest VM with
# static IPs, using Ubuntu's netplan + systemd-networkd.
#
# Env:
#   MGMT_IP   - static IP for enp2s0 (management, used by kube-apiserver)
#   DATA_IF   - data-plane interface (enp3s0)
#
# IMPORTANT: This script assumes the interface names match the KVM
# virtio device order established by virt-install:
#   enp1s0  - default (virbr0)        - DHCP, internet
#   enp2s0  - k8s5g-management        - STATIC, kube-apiserver IP
#   enp3s0  - k8s5g-dataplane         - DHCP, later becomes parent of ipvlan
#
# See docs/04-troubleshooting.md #4 for why macvlan was rejected
# in favor of ipvlan on the dataplane interface.
# ------------------------------------------------------------------

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Must be run as root (or via sudo)."
  exit 1
fi

MGMT_IP="${MGMT_IP:-192.168.100.200}"
MGMT_CIDR="${MGMT_IP}/24"
NETPLAN_FILE="/etc/netplan/50-static.yaml"

if [[ -f "${NETPLAN_FILE}" ]]; then
  cp "${NETPLAN_FILE}" "${NETPLAN_FILE}.bak.$(date +%s)"
fi

echo "[+] Writing ${NETPLAN_FILE}"
tee "${NETPLAN_FILE}" > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:
      dhcp4: true
    enp2s0:
      dhcp4: false
      addresses: [${MGMT_CIDR}]
    enp3s0:
      dhcp4: true
EOF

chmod 600 "${NETPLAN_FILE}"

echo "[+] Removing any conflicting netplan files"
# OnRamp's router role may have written aether-*.yaml files.
for f in /etc/netplan/*.yaml; do
  [[ "$f" == "${NETPLAN_FILE}" ]] && continue
  if grep -q "aether\|k8s5g" "$f" 2>/dev/null; then
    echo "    moving $f aside"
    mv "$f" "/root/$(basename "$f").disabled.$(date +%s)"
  fi
done

echo "[+] Applying netplan"
netplan apply

sleep 2
echo
echo "[+] Current interface state:"
ip -br a
echo
echo "[+] Routes:"
ip route
echo
echo "[+] Verification — ping the host bridge:"
ping -c 2 192.168.100.1 || true