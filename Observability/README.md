# Observability

Prometheus + Grafana stack for monitoring the SD-Core 5G core.

## Components

| Component | Purpose | Namespace |
|---|---|---|
| kube-prometheus-stack | Prometheus + Grafana + Alertmanager + Operator | monitoring |
| 5G Dashboard | SD-Core metrics visualization | monitoring |
| ServiceMonitors | Prometheus scrape configs for SD-Core NFs | aether-5gc |

## Quick Start

# Install the monitoring stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.sidecar.dashboards.searchNamespace=ALL

# Access Grafana (admin / prom-operator)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

SD-Core Metrics

The following SD-Core components expose Prometheus metrics:
NF	Metrics	Endpoint
AMF	UE registration, SBI requests	:9089
SMF	PDU sessions, SBI requests	:9089
UPF	Datapath counters (rel-3.x: not exposed to metricfunc)	N/A

Known limitation: In SD-Core rel-3.x, only AMF and SMF publish metrics to the
metricfunc aggregator. The UPF does not expose datapath metrics in AF_PACKET
mode. Dashboard panels for "gNB Status" and "UPF Throughput" remain empty.

See docs/04-troubleshooting.md for the full analysis.
Files

    values.yaml — Helm values for kube-prometheus-stack

    dashboard-import.md — How to import the 5G Dashboard

    servicemonitor.yaml — Custom ServiceMonitor for SD-Core (if needed)
