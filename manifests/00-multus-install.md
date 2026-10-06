# Multus CNI Installation

Multus is required because SD-Core creates `NetworkAttachmentDefinition`
custom resources for the UPF's N3 and N6 interfaces. Without Multus, the
Helm chart fails with:

no matches for kind "NetworkAttachmentDefinition" in version "k8s.cni.cncf.io/v1"


## Why This Is Manual

Aether OnRamp assumes it provisioned the cluster itself (via RKE2), in
which case Multus is installed as part of the RKE2 deployment. On a
bring-your-own kubeadm cluster, Multus must be installed explicitly
before running `make aether-5gc-install`.

## Install

kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

The thick DaemonSet is used (not thin) because it provides a central
Multus daemon per node, which is more resilient to the kind of shim
failures we hit during the SD-Core rollout.
Verify
# Pod should be Running
kubectl get pods -n kube-system -l name=multus

# CRD should exist
kubectl get crd network-attachment-definitions.k8s.cni.cncf.io

# After SD-Core install, NADs should exist
kubectl get network-attachment-definitions -n aether-5gc

Recovery: If Multus Pods Get Stuck

Symptom: all pods in aether-5gc stuck with:

plugin type="multus-shim" failed (add):
CmdAdd (shim): failed to send CNI request: Post "http://dummy/cni": EOF

Fix:

kubectl rollout restart daemonset kube-multus-ds -n kube-system

After the new Multus pod is Ready, the stuck pods recover automatically
within seconds.
Why "thick" and Not "thin"
Mode	Architecture	When to use
thin	CNI binary per pod, no daemon	Small clusters, quick tests
thick	Per-node daemon + shim	Production-shaped labs, recovery