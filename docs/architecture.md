# Architecture and Design

## Physical-to-Logical Stack

| Layer | Component | Purpose |
|---|---|---|
| Host | Laptop, Intel i7-1355U, Wi-Fi only | KVM hypervisor |
| Guest | VM `k8s5g` — Ubuntu 24.04, 8 vCPU, 24 GiB | Kubernetes node |
| Cluster | kubeadm v1.31 single-node | K8s control plane + worker |
| CNI 1 | Calico | Cluster pod networking (eth0) |
| CNI 2 | Multus + ipvlan | Data-plane networking (net1) |
| 5G Core | SD-Core rel-3.3.2 | 5G control plane |
| UPF | BESS-UPF 2.6.4-dev | User plane (AF_PACKET) |
| Monitoring | kube-prometheus-stack | Prometheus + Grafana |

## Network Design

The VM has three virtual NICs:

| NIC | libvirt network | Subnet | K8s role |
|---|---|---|---|
| enp1s0 | default (virbr0) | 192.168.122.0/24 | Internet via NAT |
| enp2s0 | k8s5g-management | 192.168.100.0/24 | API server advertise, kubelet IP |
| enp3s0 | k8s5g-dataplane | 192.168.171.0/24 | UPF data plane parent |

The kubeadm cluster uses `enp2s0` for `--apiserver-advertise-address`,
making `192.168.100.200` the stable node IP.

## Pod Networking

- **eth0** (Calico) — every pod; used for N4 (PFCP), API calls, DNS.
- **net1** (Multus + ipvlan on `enp3s0`) — attached to UPF and gNBsim
  pods; used for N3 (GTP-U).

The NetworkAttachmentDefinition is created by SD-Core Helm chart and
references the `enp3s0` master.

## Why ipvlan Instead of macvlan

macvlan assigns a unique MAC per child interface. Both VMware Workstation
and Wi-Fi APs enforce MAC-based filtering and drop frames with unexpected
source MACs. ipvlan reuses the parent MAC, satisfying both filters.

This was validated empirically: macvlan on `enp3s0` produced 100% packet
loss to external hosts; ipvlan produced working L3 connectivity.

## Why AF_PACKET Instead of DPDK

Native DPDK requires:
1. IOMMU groups (for `vfio-pci` binding)
2. 1 GiB hugepages for the datapath
3. A NIC that can be unbound from the kernel driver

On a KVM guest hosted on a Wi-Fi-only laptop:
- IOMMU groups are empty — the KVM host does not expose a virtual IOMMU.
- Wi-Fi adapters do not support SR-IOV or VFIO.
- No physical NIC is available to pass through.

AF_PACKET needs none of the above. It uses standard Linux raw sockets,
works inside any guest, and is the officially recommended mode for
non-performance deployments of SD-Core.

## Why AF_XDP/CNDP Was Also Ruled Out

AF_XDP requires native XDP support in the NIC driver. The guest's data
interface uses the `virtio_net` driver. `modinfo virtio_net | grep -i xdp`
returns nothing, and `ip link show enp3s0 | grep xdp` returns nothing.
Without native XDP, AF_XDP falls back to generic mode, which offers no
meaningful benefit over AF_PACKET.

Conclusion: **AF_PACKET is the correct engineering endpoint for this
hardware**, not a compromise. See `docs/decisions.md` for the full
decision matrix.

## 5G Core Component Map
┌───────────────────────────────────────────┐
│ SD-Core Control Plane │
│ │
N1 │ ┌──────┐ ┌──────┐ ┌──────┐ │
────────┼─▶│ AMF │───▶│ SMF │───▶│ UPF │ │
│ └──────┘ └──────┘ └──────┘ │
│ │ │ │ │
│ ▼ ▼ │ │
│ ┌──────┐ ┌──────┐ │ N4 │
│ │ UDM │ │ PCF │ │ (PFCP) │
│ └──────┘ └──────┘ │ │
│ │ │ │ │
│ ▼ ▼ │ │
│ ┌──────┐ ┌──────┐ │ │
│ │ UDR │ │ NRF │◀───────┘ │
│ └──────┘ └──────┘ │
│ │ │ │
│ ▼ ▼ │
│ ┌──────┐ ┌──────┐ │
│ │ AUSF │ │ NSSF │ │
│ └──────┘ └──────┘ │
└───────────────────────────────────────────┘


**Interfaces used in this lab:**
- **N1** — UE ↔ AMF (simulated by gnbsim)
- **N2** — gNB ↔ AMF (simulated by gnbsim)
- **N3** — gNB ↔ UPF (GTP-U on `net1`)
- **N4** — SMF ↔ UPF (PFCP, port 8805)
- **N6** — UPF ↔ data network (not used in basic test)

## HugePages

**In the KVM guest**, 1 GiB hugepages were reserved for the UPF pod:
GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt default_hugepagesz=1G hugepagesz=1G hugepages=4"


`kubectl describe node k8s5g` shows `hugepages-1Gi: 4Gi` in Allocatable.
SD-Core's UPF pod requests `hugepages-1Gi: 2Gi` in AF_PACKET mode for
its UMEM packet pool. (In DPDK mode the requirement would be higher and
binding to `vfio-pci` would be mandatory.)

## Deliverable Summary

| Capability | Demonstrated |
|---|---|
| 5G SA control plane deployment | ✅ |
| Multi-NIC pod networking | ✅ |
| HugePages exposed to scheduler | ✅ |
| End-to-end UE simulation | ✅ |
| Observability | ✅ (partial — see validation.md) |
| DPDK / SR-IOV | ❌ (hardware limitation, documented) |

 