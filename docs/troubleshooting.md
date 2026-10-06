# Troubleshooting Log

Every blocker encountered during the build-out, with root cause and resolution.
This is the reference for anyone (including future me) reproducing the lab.

---

## Issue #1 — HugePages Not Applied After Reboot (Rocky Linux)

**Symptom**
After editing `/etc/default/grub` and running `grub2-mkconfig -o /boot/grub2/grub.cfg`,
`/proc/meminfo` still showed `HugePages_Total: 0` and `Hugepagesize: 2048 kB`.

**Root Cause**
Rocky/RHEL 9.5+ use BLS with `GRUB_ENABLE_BLSCFG=true`. Editing
`/etc/default/grub` and running `grub2-mkconfig` no longer updates the
kernel command line for existing BLS entries.

**Fix**
grubby --update-kernel=ALL
--args="default_hugepagesz=1G hugepagesz=1G hugepages=3 intel_iommu=on iomu=pt"
reboot

**Verification**
grep -i huge /proc/meminfo
HugePages_Total: 3
Hugepagesize: 1048576 kB


---

## Issue #2 — IOMMU Groups Empty (DPDK/VFIO Blocked)

**Symptom**
dmesg | grep -i iommu

DMAR: IOMMU enabled

ls /sys/kernel/iommu_groups/
(no output)


**Root Cause**
VMware (and KVM without vIOMMU) do not expose VT-d to guests.
No IOMMU groups means `vfio-pci` binding is impossible.

**Resolution**
Pivoted the datapath to AF_PACKET. Documented DPDK as blocked.

---

## Issue #3 — Multus Pods Pending (Insufficient CPU)

**Symptom**
Warning FailedScheduling 0/1 nodes are available: 1 Insufficient cpu.

**Root Cause**
Node had only 2 allocatable vCPUs; ~950m already consumed by system pods.
UPF pod requested 3 CPU total.

**Fix**
Reduced CPU **requests** (not limits) to fit headroom. Requests drive
scheduling; limits still allow bursting.

---

## Issue #4 — macvlan Fails on VMware / Wi-Fi

**Symptom**
- Pod → node ping fails with `Destination Host Unreachable`
- Laptop → pod ping fails with 100% loss

**Root Cause**
Two layers of MAC filtering:
1. Kernel restriction: macvlan children cannot reach their parent.
2. VMware Workstation and Wi-Fi APs both drop frames with unexpected
   source MACs.

**Fix**
Switched NAD from `macvlan` to **`ipvlan` L2 mode**. ipvlan reuses the
parent NIC's MAC, so both filters are satisfied.

---

## Issue #5 — Locally-Built Images Not Found (ImagePullBackOff)

**Symptom**
Failed to pull image "omecproject/upf-epc-bess:local":
docker.io/... not found


**Root Cause**
`docker build` writes to `/var/lib/docker`. Kubelet reads from
containerd's `k8s.io` namespace. Two independent image stores.

**Fix**
docker save upf-bess:2.6.4-dev -o bess-local.tar
ctr -n=k8s.io images import bess-local.tar

And set `imagePullPolicy: Never`.

---

## Issue #6 — BESS Container: `sudo: not found`

**Symptom**
/bin/sh: 1: sudo: not found
*** Error: Cannot start BESS daemon


**Root Cause**
The `bessctl` wrapper script invokes `sudo`. The minimal container has
no `sudo` and doesn't need one (runs as root). `bessctl daemon start` is
also the wrong entry point for a container.

**Fix**
Run `bessd` directly in foreground mode:
```yaml
args:
- |
  /usr/bin/bessd -f /conf/upf.json

Issue #7 — pfcpiface: unrecognized level: "trace"

**Symptom**

FATAL pfcpiface/main.go:24 error reading conf file: unrecognized level: "trace"
Fix
Change "log_level": "trace" → "debug" in the ConfigMap.
Valid levels: debug, info, warn, error.

Gotcha
Editing the live ConfigMap with kubectl edit does not persist if
upf-pod.yaml is later re-applied. The file is the source of truth.

Issue #8 — pfcpiface: unable to resolve hostname upf

**Symptom**

FATAL pfcpiface/upf.go:149 unable to resolve hostname upf
  lookup upf on 10.96.0.10:53: server misbehaving

Root Cause
ConfigMap had "hostname": "upf" as the PFCP NodeID. pfcpiface tried to
resolve it via CoreDNS, which returned SERVFAIL.

Fix
Set NodeID to a literal IP and pin it in the Multus annotation:

k8s.v1.cni.cncf.io/networks: '[{"name":"upf-ipvlan","ips":["192.168.170.190/24"]}]'

"cpiface": { "hostname": "192.168.170.190", ... }

Issue #9 — pfcpiface "DeadlineExceeded" Clearing BESS State

**Symptom**
ERROR pfcpiface/bess.go:1087 pdrLookup clear did not complete: DeadlineExceeded

Root Cause
pfcpiface clears existing PDR/FAR/QER state at startup. BESS was just
launched with no ports bound, so the RPCs timed out. Cosmetic, not fatal.

Verification
kubectl logs upf-bess -c pfcpiface | grep "listening for new PFCP"
# INFO pfcpiface/node.go:84 listening for new PFCP connections on [::]:8805

Issue #10 — Empty kubectl logs --previous
**Symptom**
unable to retrieve container logs for containerd://...
Root Cause
Fast-crashing containers are garbage-collected before logs are retrievable.

Fix
Use crictl directly:

crictl ps -a | grep upf
crictl logs <container-id>

Or read on-disk logs (persist regardless of lifecycle):

/var/log/pods/default_upf-bess_<POD_UID>/

Issue #11 — OnRamp hosts.ini: node1 unreachable

**Symptom**
fatal: [node1]: UNREACHABLE! => {"msg": "...aether@127.0.0.1: Permission denied"}

Root Cause
Default hosts.ini references a placeholder host node1 that resolves to
127.0.0.1 with user aether. Even after commenting the [all] entry, the
[core] and [gnbsim] groups still listed node1, which Ansible
implicitly created.

Fix
Replace every node1 reference with the real host. Use only:

[all]
192.168.100.200 ansible_user=dinesh ansible_ssh_private_key_file=~/.ssh/id_ed25519

Issue #12 — OnRamp: master_nodes group missing

**Symptom**

fatal: ... 'dict object' has no attribute 'master_nodes'

Root Cause
OnRamp playbooks expect a group named master_nodes (and worker_nodes,
gnbsim_nodes). A minimal [all] inventory doesn't define them.

Fix
Add to hosts.ini:

[master_nodes]
192.168.100.200

[worker_nodes]
192.168.100.200

[gnbsim_nodes]
192.168.100.200

Issue #13 — OnRamp: Missing sudo password

**Symptom**

fatal: ... "Missing sudo password"

Root Cause
The router role runs sudo commands; Ansible had no password for
privilege escalation.

Fix (Option A — passwordless sudo)

echo "dinesh ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/dinesh
sudo chmod 440 /etc/sudoers.d/dinesh

Fix (Option B — provide password)

192.168.100.200 ansible_user=dinesh ansible_become_password=YOUR_PASS

Issue #14 — kubelet refuses to start: "running with swap on is not supported"

**Symptom**

E1006 ... run.go:72] "command failed" err="failed to run Kubelet:
running with swap on is not supported..."

Root Cause
Ubuntu 24.04 creates /swap.img and re-enables swap on every boot if
the fstab entry survives. A reboot after an interrupted OnRamp install
brought swap back, killing kubelet — which killed all static pods
(apiserver, controller-manager, scheduler).

Fix

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo systemctl restart kubelet

Prevention
After every VM reboot, run free -h before anything else. If swap
is non-zero, kubelet is down.

Issue #15 — SD-Core Helm: "no matches for kind NetworkAttachmentDefinition"

**Symptom**

Error: unable to build kubernetes objects from release manifest:
no matches for kind "NetworkAttachmentDefinition" in version "k8s.cni.cncf.io/v1"

Root Cause
SD-Core's Helm chart creates access-net and core-net NADs. Those
require Multus CRDs. Multus was not installed on the kubeadm cluster
(OnRamp normally installs it as part of its RKE2 provisioning).

Fix

kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

Issue #16 — All SD-Core pods stuck: Multus shim failure

**Symptom**

FailedCreatePodSandBox: plugin type="multus-shim" name="multus-cni-network"
failed (add): CmdAdd (shim): failed to send CNI request: Post "http://dummy/cni": EOF

Root Cause
The Multus daemon was in a bad state after earlier network interruptions.
Stale service account token or hung socket caused every CNI request to fail.

Fix
Force a rolling restart of the Multus DaemonSet:

kubectl rollout restart daemonset kube-multus-ds -n kube-system

All stuck pods recovered within seconds.

Issue #17 — UPF pod Pending: node affinity mismatch

**Symptom**

0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector

Root Cause
UPF pod has a nodeSelector:

node-role.aetherproject.org/upf: "true"

OnRamp adds this label during its own k8s provisioning. On a kubeadm
cluster, the label was absent.

Fix

kubectl label node k8s5g node-role.aetherproject.org/upf=true

Issue #18 — Monitoring install fails: ServiceMonitor CRD missing

**Symptom**

no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"

Root Cause
make aether-amp-install expects the Prometheus Operator CRDs. On a
kubeadm cluster these don't exist.

Fix (full monitoring stack)

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

Issue #19 — Grafana: Aether dashboards not auto-loaded

**Symptom**

Grafana runs but shows no "5G Dashboard" in the dashboard list, even
though grafana-aether-dashboards ConfigMap exists.

Root Cause
The ConfigMap was created in the cattle-dashboards namespace by
Aether AMP. The standalone kube-prometheus-stack Grafana sidecar only
scans its own namespace (monitoring), and the ConfigMap lacks the
grafana_dashboard=1 label.

Fix (manual import)
kubectl get configmap grafana-aether-dashboards -n cattle-dashboards \
  -o jsonpath='{.data.5g-dashboard\.json}' > /tmp/5g-dashboard.json

Then in Grafana: Dashboards → New → Import → Upload JSON.

Fix (automated)


kubectl label configmap grafana-aether-dashboards -n cattle-dashboards \
  grafana_dashboard=1 --overwrite

helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --reuse-values \
  --set grafana.sidecar.dashboards.searchNamespace=ALL

Observability finding: Even after import, "UPF Throughput" and "gNB
Status" panels remain empty. This is expected — SD-Core rel-3.x only
publishes AMF and SMF metrics to the metricfunc aggregator. UPF metrics
are not exposed in AF_PACKET mode, and gNBsim is ephemeral (disappears
after the test).




