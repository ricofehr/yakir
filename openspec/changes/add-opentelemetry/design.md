# Design

## Context

- The leader play installs `monitoring` (Prometheus chart 28.13.0 + Grafana) on medium and
  large, then `logcollect` (Loki 7.3.0 single binary behind a basic-auth nginx gateway,
  plus Fluent Bit) on large only. `ingress` (Traefik 39.0.4) and `gitops` (Argo CD) run on
  every sizing. Ingress runs **before** monitoring; gitops runs last.
- Grafana picks up datasources from ConfigMaps/Secrets labelled
  `monitoring_grafana_datasource_label` in the monitoring namespace (sidecar). The
  Prometheus datasource is a ConfigMap template in `monitoring`. The Loki datasource is a
  Secret template in `logcollect`, because it carries the gateway password.
- Prometheus is published at `exporter.<domain>` through Traefik with no authentication.
  Grafana is published at `monitoring.<domain>`.
- Loki credentials live in Secret `loki-basic-auth` in `kube-logcollect`; the logcollect
  role generates them once and reuses them on replay.
- Chart facts checked against the pinned or candidate versions:
  - Loki's gateway already proxies `/otlp/v1/logs`.
  - Traefik 39 exposes `tracing.otlp.grpc.{enabled,endpoint,insecure}`.
  - The Prometheus chart renders `server.otlp`, `server.tsdb` and `server.exemplars` into
    the `otlp:` and `storage:` blocks of `prometheus.yml`.
  - Tempo 3.2.1 (`grafana-community`) has `tempo.metricsGenerator.{enabled,remoteWriteUrl,processor}`
    and `persistence`.
  - The operator chart defaults to cert-manager for its webhook certificate.
- NetworkPolicy is enforced by the CNI (calico by default, cilium as an option); the
  existing `loki-backend` policy relies on that already.

## Goals / Non-Goals

**Goals:**
- One switch, the `large` sizing, controls every piece of this change, so medium and small
  render byte-identical Helm values to today.
- Each role keeps owning its own component. Tracing settings for Traefik, Argo CD, Grafana
  and Loki live in those roles, behind role defaults that are off.

**Non-Goals:**
- Replacing Fluent Bit with the collector's filelog receiver, or adding a collector
  DaemonSet (agent tier).
- Shipping `Instrumentation` resources (ai-factory owns them).
- Exposing OTLP outside the cluster, multi-tenancy, or object storage (S3/RGW) for Tempo.
- Upgrading the deprecated `grafana/grafana` chart that `monitoring` already uses. It is a
  separate change, noted as a risk below.

## Decisions

### D1. One global flag and one global endpoint
`group_vars/all/global` gains:
```yaml
global_tracing_enabled: "{{ global_cluster_sizing == 'large' }}"
global_tracing_namespace: "kube-tracing"
global_otlp_grpc_endpoint: "otel-collector.{{ global_tracing_namespace }}.svc.cluster.local:4317"
global_tempo_version: "3.2.1"
global_otel_collector_version: "0.178.1"
global_otel_operator_version: "0.128.0"
```
Each consuming role gets its own `<role>_tracing_enabled: false` and `<role>_otlp_*: ""` in
`defaults/main.yml`, mapped from the globals in `group_vars/leader/<role>`, following the
repository's rule that environment values belong in group_vars and roles stay overridable.
The playbook gates the `tracing` role with `when: global_tracing_enabled | bool`.

*Alternative:* gate on `global_cluster_sizing == "large"` in every role. Rejected because
the same sizing test would be repeated in five places, with no name saying why it is there.

### D2. Collector as a gateway Deployment, k8s distribution
The `opentelemetry-collector` chart runs in `mode: deployment` with 2 replicas, using the
`opentelemetry-collector-k8s` image (ghcr). That image includes `k8s_attributes`, `basicauth`
and `otlp_http`, without the full contrib image. `fullnameOverride: otel-collector` keeps
the service name stable for D1. Pipelines:

| Signal | Processors | Exporter |
|---|---|---|
| traces | memory_limiter, k8s_attributes, batch | `otlp_grpc/tempo` → `tempo.kube-tracing:4317` (insecure) |
| metrics | memory_limiter, k8s_attributes, batch | `otlp_http/prometheus` → `http://prometheus-server.kube-monitoring/api/v1/otlp` |
| logs | memory_limiter, k8s_attributes, batch | `otlp_http/loki` → `http://loki-gateway.kube-logcollect/otlp` + `basicauth/loki` |

The `kubernetesAttributes` preset supplies the processor and its ClusterRole. The sender's
own `k8s.*` resource attributes are deleted first (`resource/drop_k8s`) and the pod is
associated by connection source address only, so a pod cannot pass its signals off as
another namespace's. Loki
credentials come from a copy of `loki-basic-auth` that the tracing role writes into
`kube-tracing`. It reads the source Secret with `k8s_info` and writes it with `k8s`, the
same read-then-publish pattern `logcollect` uses for the Grafana datasource. The collector
gets them as env vars.

*Alternatives:* a DaemonSet agent + gateway (two tiers to run, and Fluent Bit already
covers node logs); annotating the source for Reflector (the Secret already exists on live
clusters without the annotation, and logcollect only writes it on first run).

### D3. Tempo single binary, local backend on a PVC
`grafana-community/tempo` 3.2.1:
- `persistence.enabled` with `global_storage_class` and 20Gi;
- `tempo.retention: 168h`, matching Loki;
- the chart's default receivers (OTLP plus Jaeger). Its service template dereferences the
  Jaeger receiver, so it cannot be dropped; D8 leaves only the OTLP and query ports reachable;
- metrics-generator enabled with `service_graphs` and `span_metrics` processors and
  `send_exemplars`, remote-writing to
  `http://prometheus-server.kube-monitoring.svc.cluster.local/api/v1/write`;
- `reportingEnabled: false`.

Self-tracing uses `OTEL_EXPORTER_OTLP_ENDPOINT` → the collector in `tempo.extraEnv`.
Every write into Tempo opens a span that flows back into Tempo, so an idle cluster would
trace itself continuously; Tempo's own spans are sampled at 10%
(`OTEL_TRACES_SAMPLER=parentbased_traceidratio`, arg `0.1`).

*Alternative:* `tempo-distributed` with Ceph RGW buckets. Rejected as too heavy for 5
workers; Loki is single binary on a filesystem too, so the two stay consistent.

### D4. Prometheus receives pushes; the ingress refuses them
When `monitoring_tracing_enabled`:
- `server.extraFlags` adds `web.enable-otlp-receiver`, `web.enable-remote-write-receiver`
  and `enable-feature=exemplar-storage` to the existing `web.enable-lifecycle`.
- the chart's own keys carry the config: `server.otlp.promote_resource_attributes`
  (service.name, service.namespace, service.instance.id, k8s.namespace.name, k8s.pod.name,
  k8s.deployment.name), `server.tsdb.out_of_order_time_window: 30m` (OTLP batches arrive
  late) and `server.exemplars.max_exemplars: 100000`. They render empty when tracing is
  off, so medium output is unchanged.

Neither receiver has authentication. To keep the existing unauthenticated
`exporter.<domain>` ingress from becoming a write path, the role adds a Traefik
`Middleware` of type `ipAllowList` with `sourceRange: [127.0.0.1/32]`, plus a second
`Ingress` for the same host. That Ingress has Prefix paths `/api/v1/write` and
`/api/v1/otlp`, uses the middleware, and backs onto the same service. Traefik ranks
routers by rule length, so the longer path rules win and answer 403. In-cluster pushes go
to the ClusterIP service and never touch Traefik. The deny Ingress is applied before the
Prometheus release that opens the receivers, so a play failing between the two never
leaves them reachable from outside.

*Alternative:* collector exposes a scrape endpoint instead of pushing. Rejected because
Tempo's metrics-generator can only remote-write, so the receiver is needed anyway.

### D5. Datasources and cross-links
Fixed datasource uids: `prometheus` already uses `PBFA97CFB590B2093` (kept), `loki`
(kept), `tempo` (new).
- **Tempo** (ConfigMap in the monitoring namespace, written by the tracing role):
  - `tracesToLogsV2` → Loki, with tags `k8s.namespace.name`→`namespace_name`,
    `k8s.pod.name`→`pod_name`, plus `filterByTraceID`, and span start/end shifts of ±5m;
  - `tracesToMetrics` → Prometheus, with rate and error queries on `traces_spanmetrics_*`;
  - `serviceMap` → Prometheus;
  - `nodeGraph.enabled`;
  - `lokiSearch` → Loki.

  It has the same Secret-vs-ConfigMap shape as Prometheus's (no credential, so ConfigMap).
  Label names follow Fluent Bit's current Loki labels (`namespace_name`, `pod_name`,
  `container_name`).
- **Loki** (existing Secret template): when `logcollect_tracing_enabled`, adds
  `derivedFields`:
  - one regex `(?:trace_?[iI][dD])"?[:=]"?(\w{32})` on the line;
  - one on the `trace_id` structured-metadata field (`matcherType: label`), both with
    `datasourceUid: tempo`.
- **Prometheus** (existing ConfigMap template): when `monitoring_tracing_enabled`, adds
  `exemplarTraceIdDestinations` for both `traceID` (Tempo's span-metric exemplars) and
  `trace_id` (OTLP exemplars), each with `datasourceUid: tempo`.

A datasource pointing at uid `tempo` before the tracing role has run is harmless: the link
renders and resolves once Tempo exists.

### D6. Emitters
- **Traefik** (`ingress` role): `tracing.otlp.enabled`, `grpc.enabled`, `grpc.endpoint`,
  `grpc.insecure: true`; the service name (`traefik`) and sample rate (1.0) are the chart
  defaults, so they are left unset. Traefik propagates
  W3C `traceparent` by default once tracing is on. Ingress runs before tracing, so spans
  are dropped until the collector exists. That is acceptable, and the next replay is a
  no-op.
- **Argo CD** (`gitops` role): `configs.params."otlp.address"` = gRPC endpoint,
  `otlp.insecure: true`.
- **Grafana** (`monitoring`): `grafana.ini.tracing.opentelemetry.otlp.address` = gRPC
  endpoint, `propagation: w3c`.
- **Loki** (`logcollect`): `loki.tracing.enabled: true` and `singleBinary.extraEnv`
  `OTEL_EXPORTER_OTLP_ENDPOINT`/`OTEL_SERVICE_NAME=loki`.
- **Tempo**: see D3.

### D7. Operator
`open-telemetry/opentelemetry-operator` 0.128.0 in `kube-tracing`:
- its webhook certificate from cert-manager, the chart default (cert-manager is installed
  earlier in the play);
- the chart's default `manager.collectorImage`, already the same k8s distribution as D2;
- no `OpenTelemetryCollector` or `Instrumentation` resources created.

The collector stays Helm-managed rather than an operator CR, so readiness gating and
replays stay plain Helm.

### D8. NetworkPolicy for Tempo
`tempo-networkpolicy.yml.j2` selects the Tempo pod. Ingress is allowed from Tempo pods
themselves on any port (internal gRPC, memberlist), and on:
- 4317/4318 from pods labelled `app.kubernetes.io/name: opentelemetry-collector` in
  `kube-tracing`;
- 3200 from namespace `kube-monitoring` (Grafana queries, Prometheus scrapes).

Egress is not restricted, because Tempo pushes to Prometheus and the collector.

### D9. Readiness and ordering
The `tracing` role runs right after `logcollect` in the leader play (it needs the
monitoring namespace and the Loki secret). It deploys:
1. the operator;
2. Tempo;
3. the collector;
4. the Tempo datasource and NetworkPolicy.

It waits with `kubectl wait pod --namespace=kube-tracing
--field-selector=status.phase!=Failed,status.phase!=Succeeded --for=condition=Ready`.
It also asserts that the monitoring namespace and the Loki secret exist, mirroring
logcollect's assert.

## Risks / Trade-offs

- [Prometheus write receivers are unauthenticated in-cluster] → Any pod can push metrics.
  This matches the existing trust model (Loki gateway aside, the observability stack is
  cluster-trusted). Tempo is fenced by D8. Prometheus could get the same fence later, but
  the remote-write source would have to be Tempo only.
- [The collector is an unauthenticated write path into Loki] → Loki itself is only
  writable through its basic-auth gateway, but the collector holds those credentials and
  accepts OTLP from any pod, so any pod can now write log lines into the single Loki tenant
  and spend its ingestion rate, starving Fluent Bit. Accepted: the spec requires one OTLP
  endpoint reachable from every namespace. The lever, once untrusted code runs in
  `ai-runners` / `ai-devpods`, is a NetworkPolicy on the collector or a logs-pipeline filter
  on the source namespace — which is trustworthy because the collector never keeps the
  sender's `k8s.*` attributes (D2).
- [Ingress router precedence] → If someone later gives the main Prometheus Ingress a
  priority annotation, the 403 router might lose. Covered by post-deploy check 7, which
  posts to `/api/v1/write` through the ingress and expects 403.
- [Collector replicas and the Loki secret copy drift] → If the Loki password is ever
  regenerated, the copy is refreshed on the next replay, because the role re-reads it
  every run. Reloader (`reloader.stakater.com/auto`) on the collector rolls it.
- [Resource pressure on 8 GB workers] → Requests are kept small: collector 100m/256Mi
  with `memory_limiter` at 80%, Tempo 200m/512Mi. Exact values are in the role defaults.
- [Chart repo churn] → `grafana/grafana` (used by monitoring) is deprecated upstream, like
  the Tempo chart there. This change uses `grafana-community` for Tempo only; migrating
  Grafana is left out of scope.
- [Spans dropped during first install] → Traefik, Argo CD and Grafana start exporting
  before the collector exists. The exporters retry and drop, without failing.

## Migration Plan

Additive. A replay on an existing `large` cluster:
- restarts Prometheus (new flags), Grafana (ini change), Loki (tracing env), Traefik and
  the Argo CD components (params ConfigMap);
- then installs the tracing namespace.

Rollback: set `global_tracing_enabled: false` and replay. That reverts every other role's
values, but it does not uninstall `kube-tracing`. Remove it with `helm uninstall` of the
three releases and `kubectl delete ns kube-tracing`; the operator CRDs stay until deleted
by hand.

### Post-deploy checks (operator, on a `large` cluster)

Not run by the agent (no cluster may be provisioned from this change). Carried into the PR
description.

1. `kubectl -n kube-tracing get pods`: operator, tempo-0 and two otel-collector pods Ready.
2. `kubectl -n kube-tracing run tg --rm -it --restart=Never --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest -- traces --otlp-endpoint=otel-collector:4317 --otlp-insecure --traces=5`,
   then search service `telemetrygen` in Grafana's Tempo datasource.
3. Open `https://monitoring.<domain>/` and find a `traefik` span for it in Tempo, with a
   `grafana` child span.
4. In Explore → Loki, a log line carrying a trace id shows a "View trace" link that opens Tempo.
5. From a span, "Logs for this span" runs a Loki query on its namespace and pod.
6. Prometheus has `traces_spanmetrics_calls_total`; enabling exemplars on a
   `traces_spanmetrics_latency_bucket` panel shows clickable exemplars.
7. `curl -sk -o /dev/null -w '%{http_code}' -X POST https://exporter.<domain>/api/v1/write` → `403`;
   `curl -sk https://exporter.<domain>/api/v1/query?query=up` still answers.
8. A second run of the leader play with `--tags tracing` reports no `changed` task.
