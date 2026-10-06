#!/usr/bin/env bash
# ------------------------------------------------------------------
# 04-kubeadm-init.sh
#
# Initializes a single-node kubeadm cluster with:
#   - apiserver advertised on the management NIC (enp2s0)
#   - pod CIDR 192.168.0.0/16 (Calico-compatible)
#   - control-plane taint removed (so workloads schedule on this node)
#   - Calico CNI installed
#   - Multus CNI installed (prerequisite for SD-Core NADs)
#
# Run as root, after 03-k8s-prereqs.sh and a reboot.
#
# See docs/04-troubleshooting.md #15 for the Multus/Helm ordering issue.
# ------------------------------------------------------------------

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Must be run as root (or via sudo)."
  exit 1
fi

MGMT_IP="${MGMT_IP:-192.168.100.200}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
CALICO_VERSION="${CALICO_VERSION:-v3.28.0}"

echo "[+] Sanity checks"
if swapon --show | grep -q .; then
  echo "ERROR: swap is still on. Run 03-k8s-prereqs.sh first and reboot."
  exit 1
fi

if [[ -f /etc/kubernetes/admin.conf ]]; then
  echo "[=] Cluster already initialized. Skipping kubeadm init."
else
  echo "[+] Running kubeadm init"
  kubeadm init \
    --apiserver-advertise-address="${MGMT_IP}" \
    --pod-network-cidr="${POD_CIDR}" \
    --node-name="$(hostname -s)"
fi

echo "[+] Configuring kubectl for the invoking user"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
mkdir -p "${TARGET_HOME}/.kube"
cp -f /etc/kubernetes/admin.conf "${TARGET_HOME}/.kube/config"
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.kube"

# Make it work for root too
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config

echo "[+] Removing control-plane taint (single-node cluster)"
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

echo "[+] Installing Calico ${CALICO_VERSION}"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

echo "[+] Installing Multus (thick DaemonSet)"
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

echo
echo "[+] Waiting for core pods to be Ready (this can take 2-3 minutes)"
kubectl wait --for=condition=Ready pod \
  -l k8s-app=calico-node -n kube-system --timeout=300s || true
kubectl wait --for=condition=Ready pod \
  -l name=multus -n kube-system --timeout=300s || true

echo
echo "[+] Cluster status:"
kubectl get nodes -o wide
kubectl get pods -A