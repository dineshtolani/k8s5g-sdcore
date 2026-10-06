# Validation Evidence

All claims in this repo are backed by output captured on the working
system. Reproduce with `scripts/05-validate-lab.sh`.

---

## 1. Kubernetes Cluster Health
$ kubectl get nodes
NAME STATUS ROLES AGE VERSION
k8s5g Ready control-plane 3h v1.31.14

$ kubectl get pods -A | grep -E "calico|multus|coredns"
kube-system calico-kube-controllers-... 1/1 Running
kube-system calico-node-... 1/1 Running
kube-system coredns-... 1/1 Running
kube-system kube-multus-ds-... 1/1 Running


---

## 2. SD-Core Control Plane
$ kubectl get pods -n aether-5gc
NAME READY STATUS
amf-... 1/1 Running
ausf-... 1/1 Running
kafka-controller-0 1/1 Running
metricfunc-... 1/1 Running
mongodb-0 1/1 Running
mongodb-1 1/1 Running
mongodb-arbiter-0 1/1 Running
nrf-... 1/1 Running
nssf-... 1/1 Running
pcf-... 1/1 Running
simapp-... 1/1 Running
smf-... 1/1 Running
udm-... 1/1 Running
udr-... 1/1 Running
upf-0 5/5 Running
webui-... 1/1