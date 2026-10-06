# k8s5g-sdcore-lab

End-to-end deployment of an open-source **5G Standalone Core** (SD-Core) on a
single-node Kubernetes cluster, running on nested virtualization. Includes
full control plane (AMF, SMF, NRF, AUSF, UDM, UDR, PCF, NSSF, WebUI) and a
containerized UPF, validated with a gNB/UE simulator.

The repository documents the **entire journey** — design decisions, dead ends,
hardware limitations discovered, and every troubleshooting step required to
reach a working system.

---

## Final State

| Component | Status |
|---|---|
| Kubernetes (kubeadm, single node) | ✅ Running |
| Calico CNI | ✅ Running |
| Multus CNI + ipvlan | ✅ Working |
| HugePages (guest) | ✅ Reserved |
| SD-Core control plane (10 NFs) | ✅ Running |
| BESS-UPF (AF_PACKET datapath) | ✅ Running |
| gNBsim end-to-end test | ✅ 5/5 UEs PASS |
| Prometheus + Grafana monitoring | ✅ Running |
| 5G Dashboard | ✅ Partially populated (SMF/AMF metrics) |

---

## Architecture
┌─────────────────────────────────────────────────────────────┐
│ Laptop (KVM host) │
│ │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ VM: k8s5g (Ubuntu 24.04, 8 vCPU, 24 GiB) │ │
│ │ │ │
│ │ ┌────────────────────────────────────────────────┐ │ │
│ │ │ kubeadm single-node cluster (K8s v1.31) │ │ │
│ │ │ │ │ │
│ │ │ Namespace: aether-5gc │ │ │
│ │ │ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │ │
│ │ │ │ AMF │ │ SMF │ │ NRF │ ... │ │ │
│ │ │ └──────────┘ └──────────┘ └──────────┘ │ │ │
│ │ │ │ │ │ │ │
│ │ │ └──────┬──────┘ │ │ │
│ │ │ ▼ │ │ │
│ │ │ ┌──────────┐ │ │ │
│ │ │ │ UPF-0 │ (BESS, AF_PACKET mode) │ │ │
│ │ │ └──────────┘ │ │ │
│ │ │ │ │ │ │
│ │ │ ▼ │ │ │
│ │ │ net1 (Multus / ipvlan) │ │ │
│ │ └────────────────────────────────────────────────┘ │ │
│ │ │ │
│ │ enp1s0 (NAT) enp2s0 (mgmt) enp3s0 (data) │ │
│ └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘


See `docs/architecture.md` for detailed topology and design decisions.

---

## Quick Start

> **Note:** The full lab requires manual steps that vary by environment.
> This repo documents *the working configuration*, not a one-command installer.

1. Read `docs/decisions.md` to understand the constraints.
2. Read `docs/troubleshooting.md` — the 15+ issues encountered are all here.
3. Follow `scripts/` in numeric order to reproduce.
4. Validate with `scripts/05-validate-lab.sh`.

---

## Key Findings

1. **DPDK is not achievable on this hardware** — no IOMMU passthrough
   on the KVM guest, no SR-IOV on a Wi-Fi-only laptop. AF_PACKET is the
   correct datapath for this environment. See `docs/decisions.md` §DPDK.
2. **AF_XDP/CNDP blocked** — `virtio_net` driver in the guest does not
   expose native XDP. Investigated and ruled out with evidence.
3. **Aether OnRamp assumes RKE2, not kubeadm** — multiple adaptations
   required: Multus must be pre-installed, the `upf=true` node label must
   be added manually, and monitoring needs a Prometheus Operator first.
4. **macvlan does not work on VMware or Wi-Fi** — MAC filtering on both
   drops frames. ipvlan L2 is the portable solution.
5. **Ubuntu 24.04 uses Netplan + systemd-networkd** — required for
   OnRamp's `router` role to function. NetworkManager breaks it.

---

## Stack Versions

| Component | Version |
|---|---|
| Ubuntu | 24.04.5 LTS |
| Kernel | 6.8.0-146-generic |
| Kubernetes | v1.31.14 |
| containerd | 2.x |
| Calico | (installed via manifest) |
| Multus | thick DaemonSet |
| SD-Core | rel-3.3.2 (Helm chart 5.0.0) |
| BESS-UPF | upf-bess 2.6.4-dev (locally built) |
| Aether OnRamp | latest (as of build date) |

---

## What This Project Demonstrates

- **CNF deployment** on Kubernetes with multi-NIC CNI
- **5G SA core** end-to-end deployment and validation
- **Systematic troubleshooting** across virtualization, networking,
  Kubernetes, and 5G layers
- **Evidence-based engineering decisions** (documented rejections of
  DPDK/AF_XDP with specific technical justification)
- **Observability** with Prometheus and Grafana

