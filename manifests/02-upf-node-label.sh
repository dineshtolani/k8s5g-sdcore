#!/usr/bin/env bash
# ------------------------------------------------------------------
# 02-upf-node-label.sh
#
# Applies the node label required by the SD-Core UPF pod's nodeSelector.
#
# Background: OnRamp adds this label during its own RKE2 provisioning
# step. On a bring-your-own kubeadm cluster, the label is absent, and
# the UPF pod stays Pending with:
#   "0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector"
#
# See docs/04-troubleshooting.md #17.
#
# Run after kubeadm init and Calico are working, before
# `make aether-5gc-install`.
# ------------------------------------------------------------------

set -euo pipefail

NODE_NAME="${1:-$(hostname -s)}"

echo "[+] Applying UPF node label to: ${NODE_NAME}"
kubectl label node "${NODE_NAME}" \
  node-role.aetherproject.org/upf=true \
  --overwrite

echo
echo "[+] Verifying:"
kubectl get node "${NODE_NAME}" \
  -o jsonpath='{.metadata.labels}' | tr ',' '\n' | grep aetherproject
echo
echo "[+] Done. UPF pod will now schedule on this node."