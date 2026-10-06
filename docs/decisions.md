# Design Decisions

Each decision below is documented with the alternatives considered and
the technical reason the choice was made. This is the "why" behind the
architecture.

---

## D1 — Single-node vs 3-node cluster

**Decision:** Single-node kubeadm cluster, 8 vCPU / 24 GiB.

**Alternatives:**
- 3 nodes × 4 vCPU / 8 GiB each

**Reason:** SD-Core's AMF alone requests 2 CPU / 4 GiB. On an 8 GiB node
after system overhead, allocatable memory is ~6 GiB. AMF consumes most
of it; SMF, MongoDB, Kafka, and 8 other components cannot fit. The 3-node
plan would fail scheduling. The single-node 8/24 configuration is
OnRamp's documented Quick Start baseline.

---

## D2 — kubeadm vs RKE2

**Decision:** kubeadm (bring-your-own cluster).

**Alternatives:**
- Let OnRamp install RKE2 (`make aether-k8s-install`)

**Reason:** kubeadm was already used successfully in the earlier VMware
lab. Choosing kubeadm kept the skill set continuous and gave full control
over the CNI. The trade-off is that OnRamp's assumptions about RKE2
(Multus pre-installed, node labels applied, monitoring stack present)
had to be satisfied manually — which is documented in
`docs/troubleshooting.md` as Issues #15, #16, #17, #18.

---

## D3 — ipvlan vs macvlan

**Decision:** ipvlan L2 mode.

**Alternatives:**
- macvlan bridge mode

**Reason:** macvlan assigns a unique MAC per child. Both VMware
Workstation and Wi-Fi APs drop frames with unknown source MACs.
ipvlan reuses the parent MAC, satisfying both filters. Validated
empirically: macvlan produced 100% packet loss to external hosts,
ipvlan produced working L3.

---

## D4 — AF_PACKET vs DPDK

**Decision:** AF_PACKET.

**Alternatives:**
- DPDK with vfio-pci binding

**Reason:** DPDK requires IOMMU groups, hugepages for the datapath, and
the ability to unbind a physical NIC from its kernel driver. On a KVM
guest hosted on a Wi-Fi-only laptop:
- `ls /sys/kernel/iommu_groups/` is empty — no vIOMMU exposed.
- No physical NIC is available to pass through.
- Wi-Fi adapters do not support SR-IOV.

AF_PACKET needs none of these and is SD-Core's documented mode for
non-performance deployments.

---

## D5 — AF_XDP/CNDP considered and rejected

**Decision:** Do not pursue AF_XDP.

**Alternatives:**
- CNDP (Cloud Native Data Plane) over AF_XDP

**Reason:** AF_XDP requires native XDP support in the NIC driver. The
guest's data interface uses `virtio_net`. Verified on the VM: