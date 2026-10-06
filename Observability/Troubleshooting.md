Grafana shows "No data" for all panels

    Check Prometheus targets: http://localhost:9090/targets

    Look for metricfunc target — should be "Up"

    If down, check ServiceMonitor labels match Prometheus selector

5G Dashboard not visible

See dashboard-import.md — the ConfigMap is in the wrong namespace and
lacks the sidecar label by default.
Grafana pod CrashLooping
bash

kubectl logs -n monitoring deploy/prometheus-grafana -c grafana
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana


---

## How to Use

**Place in repo:**


mkdir -p observability
# Paste the five files above

Install the stack:

cd ~/k8s5g-sdcore-lab
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f observability/values.yaml

Import the 5G Dashboard:

Follow observability/dashboard-import.md — manual import is the fastest path.

Take screenshots:

Once Grafana is up:

    5G Dashboard showing Active PDU Sessions = 5, Subscribers = 5, UPF = Up

    Prometheus /targets showing metricfunc target Up

    These go into docs/ alongside the Radar topology screenshot