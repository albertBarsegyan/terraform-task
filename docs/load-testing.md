# Load testing

Run `BASE_URL=https://<domain> k6 run load-test/test.js`. Capture real results only after deployment; this repository makes no performance claim.

| Concurrency | Requests | RPS | p50 | p95 | p99 | Error rate | CPU | Memory |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | | | | | | | | |
| 25 | | | | | | | | |
| 50 | | | | | | | | |
| 100 | | | | | | | | |

Use k6 output plus Grafana panels to identify throughput, latency, error-rate and degradation point. Likely next improvements are HPA, larger/On-Demand capacity, and load-test-specific tuning.
