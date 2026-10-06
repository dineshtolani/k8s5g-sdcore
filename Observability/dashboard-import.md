# 5G Dashboard Import

The SD-Core 5G Dashboard is shipped as a ConfigMap by Aether AMP
(`grafana-aether-dashboards` in the `cattle-dashboards` namespace).

## Why It Doesn't Auto-Load

The standalone `kube-prometheus-stack` Grafana sidecar only scans its own
namespace (`monitoring`) by default. The Aether AMP ConfigMap is in
`cattle-dashboards` and lacks the `grafana_dashboard=1` label.

## Fix Option 1: Manual Import (Fastest)

```bash
# Extract the dashboard JSON
kubectl get configmap grafana-aether-dashboards -n cattle-dashboards \
  -o jsonpath='{.data.5g-dashboard\.json}' > /tmp/5g-dashboard.json

# Verify JSON is valid
python3 -m json.tool /tmp/5g-dashboard.json > /dev/null && echo "VALID"

Then in Grafana:

    Dashboards → New → Import

    Upload /tmp/5g-dashboard.json

    Select Prometheus datasource

    Import

Fix Option 2: Automated Sidecar Discovery


# Label the ConfigMap
kubectl label configmap grafana-aether-dashboards -n cattle-dashboards \
  grafana_dashboard=1 --overwrite

# Restart Grafana to trigger re-scan
kubectl rollout restart deployment prometheus-grafana -n monitoring

After ~30s, the dashboard should appear in Grafana under a folder
named after the ConfigMap's namespace or a label-based folder.
Fix Option 3: Helm Upgrade with searchNamespace=ALL


helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --reuse-values \
  --set grafana.sidecar.dashboards.searchNamespace=ALL

Dashboard Panels and Their Metrics
Panel	PromQL Query	Status
Active PDU Sessions	smf_pdu_sessions{service="metricfunc"}	✅ Works
UPF Status	nf_status{nfType="UPF"}	✅ Works
gNodeB Status	nf_status{nfType="GNB"}	❌ No data (ephemeral gNB)
5G Core Subscribers	sum(core_subscriber) by (...)	✅ Works
UPF Throughput	upf_bytes_count{...}	❌ No data (UPF metrics gap)
UPF Subscriber Bitrate	upf_session_tx_bytes{...}	❌ No data (UPF metrics gap)
Why Some Panels Show "No data"

    gNodeB Status: gnbsim is ephemeral — it runs during make aether-gnbsim-run
    and disappears after. No gNB to scrape between runs.

    UPF Throughput / Bitrate: In SD-Core rel-3.x, only AMF and SMF publish
    metrics to metricfunc. The UPF does not expose datapath counters to
    Prometheus in AF_PACKET mode. This requires either:

        A custom UPF ServiceMonitor (if the UPF exposes /metrics)

        Migration to a UPF mode that publishes metrics (CNDP/DPDK)

        The aether-amp monitoring service (not installed in this lab)

See docs/04-troubleshooting.md Issue #19 for the full analysis.