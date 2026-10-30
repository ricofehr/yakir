# Proposal

## Why

Yakir ships metrics (Prometheus) and logs (Loki + Fluent Bit) but no traces: there is no
trace backend, no OTLP endpoint for workloads to send to, and the three Grafana
datasources do not link to one another. The `ai-*` workloads that Argo CD reconciles from
ai-factory need somewhere to send OpenTelemetry signals, and an operator debugging a slow
request needs to jump from a span to its logs and metrics. The README TODO has listed
"Work on opentelemetry integration" for a while.

## What Changes

- New `tracing` role, namespace `kube-tracing`, run last among the observability roles and
  **only on the `large` sizing** (same gate as `logcollect`):
  - **Grafana Tempo** (single binary, from the `grafana-community` chart repo; the
    `grafana/tempo` chart is deprecated) storing traces on a PVC, with its metrics-generator
    producing span metrics and service-graph metrics into Prometheus.
  - **OpenTelemetry Collector** as an in-cluster gateway: one OTLP endpoint (gRPC + HTTP)
    for every workload, routing traces to Tempo, metrics to Prometheus and logs to Loki.
  - **OpenTelemetry Operator**, so ai-factory can ship `Instrumentation` resources and
    get auto-instrumentation by annotating its pods. Yakir installs the operator only.
  - A Grafana **Tempo datasource** linked to Loki and Prometheus.
  - A NetworkPolicy limiting who can reach Tempo.
- Cross-tool telemetry settings, all gated on the `large` sizing:
  - Prometheus accepts OTLP metrics and remote-write, and stores exemplars. Those two
    write endpoints are refused through the public `exporter.<domain>` ingress.
  - The Loki datasource turns a trace id in a log line into a link to Tempo. The Prometheus
    datasource links exemplars to Tempo.
  - Traefik, Argo CD, Grafana, Loki and Tempo send their own spans to the collector.
- Fluent Bit stays the node/container log shipper; the collector does not replace it.
- Chart versions pinned in `ansible/group_vars/all/global`; README component table, role
  list and TODO updated; CHANGELOG entry.

## Capabilities

### New Capabilities

- `distributed-tracing`: the cluster's trace pipeline — OTLP ingest endpoint, trace
  storage and query, auto-instrumentation operator, which platform components emit spans,
  and on which sizing it is deployed.
- `telemetry-correlation`: how the metrics, logs and traces backends feed and link to each
  other — OTLP/remote-write ingest into Prometheus, exemplars, span metrics, and the
  Grafana cross-datasource links.

### Modified Capabilities

None — `openspec/specs/` is empty; this is the repository's first OpenSpec change.

## Impact

- Branch: `add-opentelemetry`
- New: `ansible/roles/tracing/`, `ansible/group_vars/leader/tracing`.
- Modified: `ansible/playbook.yml`, `ansible/group_vars/all/global`,
  `ansible/group_vars/leader/{monitoring,logcollect,ingress,gitops}` (or the files holding
  those roles' leader vars), and the `monitoring`, `logcollect`, `ingress`, `gitops` roles
  (defaults + Helm values + datasource templates).
- New Helm repos: `https://grafana-community.github.io/helm-charts`,
  `https://open-telemetry.github.io/opentelemetry-helm-charts`.
- Cluster footprint on `large`: Tempo (one pod + PVC), collector (one Deployment),
  operator (one Deployment + CRDs + webhook certificate from cert-manager).
- `small` and `medium` deployments are unchanged.
- Docs: `README.md`, `CHANGELOG/`.
