# Tasks

Verification note: no cluster may be provisioned from this change (CLAUDE.md), so the
offline gate is `ansible-lint` (profile production, run from `ansible/`) plus `helm
template` of each chart with the values the role passes. Live checks are listed in group 8
for the operator who deploys.

## 1. Globals and playbook wiring

- [x] 1.1 Add `global_tracing_enabled`, `global_tracing_namespace`, `global_otlp_grpc_endpoint`, `global_tempo_version`, `global_otel_collector_version`, `global_otel_operator_version` to `ansible/group_vars/all/global` (D1); verify `ansible-lint` is clean
- [x] 1.2 Add the `tracing` role to the leader play in `ansible/playbook.yml` right after `logcollect`, tags `["cluster", "tracing"]`, `when: global_tracing_enabled | bool`; verify with `ansible-playbook --syntax-check` / `ansible-lint`

## 2. tracing role — Tempo, collector, operator

- [x] 2.1 Scaffold `ansible/roles/tracing/{defaults,vars,tasks,templates}` and `ansible/group_vars/leader/tracing` (namespace `kube-tracing`, versions, endpoints, storage class, retention, resources, monitoring/logcollect namespaces); repo URLs in `vars/main.yml`; verify files lint clean
- [x] 2.2 Tasks: create namespace; assert the monitoring namespace and `loki-basic-auth` exist; read the Loki secret and publish a copy in `kube-tracing` with `no_log` (D2); verify the task runs idempotently by construction (`k8s` module, `state: present`)
- [x] 2.3 Deploy the OpenTelemetry Operator chart with cert-manager webhook certs and the chart's default `manager.collectorImage` (D7); verify `helm template` of 0.128.0 with those values renders a cert-manager `Certificate`
- [x] 2.4 Deploy Tempo from `grafana-community` with PVC, retention, OTLP receivers only, metrics-generator (service graphs + span metrics + exemplars → Prometheus remote write), self-tracing env, reporting off (D3); verify `helm template` renders a `tempo.yaml` containing `metrics_generator` and the remote-write URL
- [x] 2.5 Deploy the collector chart as a 2-replica gateway with the k8s image, `fullnameOverride: otel-collector`, the `kubernetesAttributes` preset, the three pipelines, `basicauth/loki` from the secret copy env vars, and the reloader annotation (D2); verify `helm template` renders a Service `otel-collector` exposing 4317/4318 and a config with all three pipelines
- [x] 2.6 Template `tempo-datasource.yml.j2` (uid `tempo`, tracesToLogsV2, tracesToMetrics, serviceMap, nodeGraph, lokiSearch) into the monitoring namespace with the datasource label (D5); verify the rendered YAML parses with `yq`
- [x] 2.7 Template `tempo-networkpolicy.yml.j2` (D8); verify it parses with `yq` and its pod selector matches the labels in Tempo's `helm template` output
- [x] 2.8 Add the terminal-pod-excluding readiness wait for `kube-tracing` (D9); verify the command carries `--field-selector=status.phase!=Failed,status.phase!=Succeeded`

## 3. monitoring role — Prometheus receivers, exemplars, Grafana self-tracing

- [x] 3.1 Add `monitoring_tracing_enabled: false` and `monitoring_otlp_grpc_endpoint: ""` to defaults, mapped from the globals in `group_vars/leader/monitoring`; verify lint
- [x] 3.2 When enabled, extend Prometheus `server.extraFlags` and set `server.otlp` / `server.tsdb` / `server.exemplars` (otlp promotion, OOO window, exemplars) (D4); verify `helm template` of prometheus 28.13.0 with the values renders the three flags and the config keys, and with tracing off renders the same values as `main`
- [x] 3.3 When enabled, add the Traefik `Middleware` (ipAllowList 127.0.0.1/32) and the write-path `Ingress` on the exporter host (D4); verify the manifests parse and the paths are `/api/v1/write` and `/api/v1/otlp`
- [x] 3.4 When enabled, add `exemplarTraceIdDestinations` to `prometheus-datasource.yml.j2` (D5) and the Grafana `grafana.ini` tracing block (D6); verify templating with tracing on and off

## 4. logcollect role — Loki derived fields and self-tracing

- [x] 4.1 Add `logcollect_tracing_enabled: false` / `logcollect_otlp_grpc_endpoint: ""` defaults mapped in `group_vars/leader/logcollect`; when enabled, add `derivedFields` to `loki-datasource.yml.j2` and Loki tracing values (D5, D6); verify the datasource template renders valid YAML both ways and `helm template` of loki 7.3.0 shows the env on the single-binary pod

## 5. ingress and gitops roles — Traefik and Argo CD spans

- [x] 5.1 Add `ingress_tracing_enabled` / `ingress_otlp_grpc_endpoint` defaults + group_vars mapping and the conditional `tracing.otlp` values (D6); verify `helm template` of traefik 39.0.4 renders `--tracing.otlp.grpc.endpoint=` when on and no tracing args when off
- [x] 5.2 Add `gitops_tracing_enabled` / `gitops_otlp_grpc_endpoint` defaults + group_vars mapping and the conditional `otlp.address` param (D6); verify the rendered `argocd-cmd-params-cm` contains `otlp.address` only when on

## 6. Documentation

- [x] 6.1 README: add the `tracing` role to the role tree, Tempo / OpenTelemetry Collector / OpenTelemetry Operator rows to the component table, a short "Tracing" section (OTLP endpoint, how ai-factory instruments a pod, Grafana correlation, large-only), and replace the TODO line; verify the rendered table columns line up with the existing ones
- [x] 6.2 CHANGELOG-1.5.md: add Feature entries in the file's style; verify the section headers are unchanged

## 7. Static gate

- [x] 7.1 Run `cd ansible && ansible-lint` (production profile), `shellcheck up deploy-to-libvirt`, and `tflint --chdir=tf/libvirt`; all clean

## 8. Live verification (operator, after a `large` deploy — not run by the agent)

- [x] 8.1 Write the post-deploy checks (pods Ready in `kube-tracing`; a `telemetrygen traces` job reaches Tempo; Traefik spans for a `monitoring.<domain>` request; Loki log → Tempo link; Tempo span → Loki logs; `traces_spanmetrics_calls_total` with exemplars; `POST https://exporter.<domain>/api/v1/write` → 403; replay with no `changed`) into design.md "Post-deploy checks"; verify the section lists all eight
