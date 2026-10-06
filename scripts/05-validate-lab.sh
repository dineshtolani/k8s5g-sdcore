#!/usr/bin/env bash
# ------------------------------------------------------------------
# 05-validate-lab.sh
#
# End-to-end validation of the SD-Core 5G core.
#
# Checks:
#   1. Kubernetes node Ready
#   2. Core CNIs running (Calico, Multus, CoreDNS)
#   3. SD-Core control-plane pods Running
#   4. UPF pod Running with hugepages satisfied
#   5. PFCP (N4) port 8805 listening
#   6. metricfunc reports UPF Connected
#   7. gnbsim summary (if a run has completed)
#
# Produces a validation-evidence.txt file in the repo root.
# ------------------------------------------------------------------

set -euo pipefail

OUT="validation-evidence.txt"
: > "${OUT}"

section() {
  echo "" | tee -a "${OUT}"
  echo "=== $* ===" | tee -a "${OUT}"
  echo "" | tee -a "${OUT}"
}

run() {
  echo "\$ $*" | tee -a "${OUT}"
  "$@" 2>&1 | tee -a "${OUT}" || true
}

section "1. Node status"
run kubectl get nodes -o wide

section "2. Cluster CNI and core pods"
run kubectl get pods -n kube-system -o wide

section "3. SD-Core control-plane pods"
run kubectl get pods -n aether-5gc -o wide

section "4. UPF pod details (hugepages, node selector)"
run kubectl describe pod -n aether-5gc -l app=upf

section "5. PFCP listener (N4)"
UPF_POD=$(kubectl get pod -n aether-5gc -l app=upf -o jsonpath='{.items[0].metadata.name}')
if [[ -n "${UPF_POD}" ]]; then
  echo "\$ kubectl exec ${UPF_POD} -c pfcpiface -- ss -lunp | grep 8805" | tee -a "${OUT}"
  kubectl exec -n aether-5gc "${UPF_POD}" -c pfcpiface -- \
    sh -c 'ss -lunp 2>/dev/null | grep 8805 || netstat -lunp 2>/dev/null | grep 8805' \
    2>&1 | tee -a "${OUT}" || true
fi

section "6. metricfunc UPF status"
MF_POD=$(kubectl get pod -n aether-5gc -l app=metricfunc -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "${MF_POD}" ]]; then
  MF_IP=$(kubectl get pod -n aether-5gc "${MF_POD}" -o jsonpath='{.status.podIP}')
  echo "\$ curl http://${MF_IP}:9301/nmetric-func/v1/nfstatus/UPF" | tee -a "${OUT}"
  curl -s "http://${MF_IP}:9301/nmetric-func/v1/nfstatus/UPF" | tee -a "${OUT}" || true
fi

section "7. gnbsim summary (if present)"
if kubectl get pods -n aether-5gc -l app=gnbsim --no-headers 2>/dev/null | grep -q .; then
  GNBSIM=$(kubectl get pod -n aether-5gc -l app=gnbsim -o jsonpath='{.items[0].metadata.name}')
  kubectl logs -n aether-5gc "${GNBSIM}" 2>&1 | tail -30 | tee -a "${OUT}" || true
else
  echo "(gnbsim not currently deployed — run \`make aether-gnbsim-run\`)" | tee -a "${OUT}"
fi

section "8. Node allocatable resources"
run kubectl describe node "$(hostname -s)"

section "9. HugePages"
echo "\$ grep -i huge /proc/meminfo" | tee -a "${OUT}"
grep -i huge /proc/meminfo | tee -a "${OUT}"

echo
echo "[+] Evidence written to: ${OUT}"