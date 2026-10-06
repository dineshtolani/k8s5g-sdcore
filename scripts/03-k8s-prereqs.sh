#!/usr/bin/env bash
# ------------------------------------------------------------------
# 03-k8s-prereqs.sh
#
# Prepares Ubuntu 24.04 for kubeadm:
#   - disables swap (permanently)
#   - loads overlay + br_netfilter kernel modules
#   - sets required sysctls
#   - installs and configures containerd
#   - installs kubelet, kubeadm, kubectl
#
# Run as root. Idempotent — safe to re-run.
#
# See docs/04-troubleshooting.md #14 for the swap-reactivation trap
# that killed kubelet on every reboot until fixed.
# ------------------------------------------------------------------

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Must be run as root (or via sudo)."
  exit 1
fi

K8S_VERSION="${K8S_VERSION:-v1.31}"

# ---------- 1. Disable swap (permanently) ----------
echo "[+] Disabling swap"
swapoff -a
# Comment out any swap entry in fstab
sed -i '/\sswap\s/s/^/#/' /etc/fstab
# Disable the systemd swap unit that Ubuntu 24.04 creates
if systemctl list-unit-files | grep -q '^swap.img.swap'; then
  systemctl mask swap.img.swap || true
fi
free -h | grep -i swap

# ---------- 2. Kernel modules ----------
echo "[+] Loading kernel modules"
tee /etc/modules-load.d/k8s.conf > /dev/null <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# ---------- 3. Sysctl ----------
echo "[+] Configuring sysctls"
tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# ---------- 4. containerd ----------
echo "[+] Installing containerd"
apt-get update -qq
apt-get install -y -qq containerd apt-transport-https ca-certificates curl gpg

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# Required for kubeadm's systemd cgroup manager
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# ---------- 5. Kubernetes repo + packages ----------
echo "[+] Adding Kubernetes apt repo (${K8S_VERSION})"
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo
echo "[+] Versions installed:"
kubeadm version -o short
kubelet --version
kubectl version --client --short 2>/dev/null || kubectl version --client