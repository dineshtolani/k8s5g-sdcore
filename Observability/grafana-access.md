markdown

# Accessing Grafana

## Via NodePort (Persistent)

If Grafana was installed with `grafana.service.type=NodePort`:

kubectl get svc -n monitoring prometheus-grafana
# Note the NodePort (e.g., 32157)

Access from your laptop:
text

http://192.168.100.200:32157

Or via the VM's NAT IP:

http://192.168.122.226:32157

Via Port-Forward (Temporary)


# From your laptop — SSH tunnel
ssh -L 3000:127.0.0.1:3000 dinesh@192.168.100.200

# On the VM — forward to Grafana service
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

Then browse to http://localhost:3000.
Credentials
Field	Value
Username	admin
Password	prom-operator (default)

To retrieve the generated password:


kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo

Prometheus UI


# Port-forward
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Or NodePort
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus

Access at http://localhost:9090. The Targets page (/targets) shows
all scrape targets and their health.