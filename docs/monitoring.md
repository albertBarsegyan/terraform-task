# Monitoring and logging

`kube-prometheus-stack` supplies Prometheus, Grafana, kube-state-metrics, and node-exporter. Pod annotations cause Prometheus to scrape `/metrics`; the dashboard also uses container and node metrics. Access Grafana safely with `make grafana`, rather than exposing it through the application ALB.

Loki runs in single-binary mode and Alloy runs as a DaemonSet. Alloy labels records with `namespace`, `pod`, `container`, and `app`. Query application JSON logs with `{namespace="demo", app="demo-app"}`.
