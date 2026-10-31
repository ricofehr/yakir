# Spec Delta

## Purpose

Makes the metrics, logs and traces backends of a yakir cluster feed and link to one
another. An operator can move from a span to its logs and metrics, and back, in Grafana.

## ADDED Requirements

### Requirement: Prometheus ingests pushed metrics
On the `large` sizing, Prometheus SHALL accept metrics pushed over OTLP and over the
remote-write protocol, from inside the cluster. OTLP resource attributes `service.name`,
`service.namespace`, `k8s.namespace.name` and `k8s.pod.name` SHALL become labels.

#### Scenario: OTLP metrics from the collector
- **WHEN** the collector forwards an OTLP counter from service `litellm`
- **THEN** Prometheus stores the series with a `service_name="litellm"` label

#### Scenario: Span metrics from the trace store
- **WHEN** the trace store produces span metrics and service-graph metrics
- **THEN** Prometheus stores `traces_spanmetrics_*` and `traces_service_graph_*` series

### Requirement: Push endpoints are not reachable through the ingress
The Prometheus write endpoints (`/api/v1/write` and `/api/v1/otlp/`) SHALL be refused on
the public `exporter.<domain>` ingress host, while the rest of the Prometheus UI and API
stays reachable there as before.

#### Scenario: Write attempt through the ingress
- **WHEN** a client posts to `https://exporter.<domain>/api/v1/write`
- **THEN** the ingress answers `403` and nothing is written

#### Scenario: Query through the ingress
- **WHEN** a client requests `https://exporter.<domain>/api/v1/query?query=up`
- **THEN** the query is answered as before this change

### Requirement: Prometheus stores exemplars
On the `large` sizing, Prometheus SHALL store exemplars, so a metric sample can carry the
trace id that produced it.

#### Scenario: Span metric with exemplar
- **WHEN** the trace store remote-writes a span-metrics histogram with exemplars
- **THEN** querying exemplars for that series in Prometheus returns entries labelled with
  the trace id (`traceID` from the trace store, `trace_id` from OTLP metrics)

### Requirement: Logs link to traces
The Grafana Loki datasource SHALL turn a trace id found in a log line or in the
`trace_id` structured-metadata field into a link that opens the trace in Tempo.

#### Scenario: Log line carrying a trace id
- **WHEN** a user views a log line containing `"trace_id":"4bf92f3577b34da6a3ce929d0e0e4736"`
  in Grafana Explore
- **THEN** the line offers a Tempo link that opens trace `4bf92f3577b34da6a3ce929d0e0e4736`

### Requirement: Traces link to logs and metrics
The Grafana Tempo datasource SHALL link a span to its logs in Loki, filtered on the span's
namespace and pod and on its trace id. It SHALL also link a span to request-rate and
error-rate queries in Prometheus, and show a service graph and node graph built from the
trace store's metrics.

#### Scenario: Span to logs
- **WHEN** a user opens a span from a pod in `ai-llm` and follows "Logs for this span"
- **THEN** Grafana runs a Loki query scoped to that namespace and pod, filtered on the trace id,
  over the span's time range

#### Scenario: Service graph
- **WHEN** a user opens the Service Graph tab of the Tempo datasource
- **THEN** a graph of services and their call rates is shown

### Requirement: Metrics link to traces
The Grafana Prometheus datasource SHALL link exemplars to the trace in Tempo.

#### Scenario: Exemplar on a panel
- **WHEN** a user enables exemplars on a span-metrics latency panel and clicks an exemplar
- **THEN** Grafana opens the referenced trace in Tempo

### Requirement: Correlation settings follow the sizing gate
On `small` and `medium` sizings, the Prometheus server flags, the Prometheus and Loki
datasources, and the Traefik, Argo CD, Grafana and Loki tracing settings SHALL remain
exactly as before this change.

#### Scenario: Medium cluster
- **WHEN** the playbook runs with sizing `medium`
- **THEN** the Prometheus datasource has no exemplar trace destination and Prometheus runs
  without the OTLP and remote-write receivers
