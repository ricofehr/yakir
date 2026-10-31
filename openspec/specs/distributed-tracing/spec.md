# distributed-tracing Specification

## Purpose
Gives workloads on a yakir cluster one in-cluster OpenTelemetry endpoint and a trace store
queryable from Grafana. It also makes the platform's own components emit spans, so a
request can be followed from the ingress to the application.

## Requirements

### Requirement: Tracing stack is deployed on the large sizing only
The tracing stack SHALL be deployed when the cluster sizing is `large` and SHALL NOT be
deployed on `small` or `medium`. Every tracing-related setting added to other components
SHALL follow the same gate.

#### Scenario: Large cluster
- **WHEN** the playbook runs with sizing `large`
- **THEN** the `kube-tracing` namespace holds a running trace store, OTLP collector and
  instrumentation operator

#### Scenario: Medium cluster
- **WHEN** the playbook runs with sizing `medium`
- **THEN** no `kube-tracing` namespace is created and Traefik, Argo CD, Grafana, Loki and
  Prometheus are configured exactly as before this change

### Requirement: Single in-cluster OTLP endpoint
The cluster SHALL expose one OTLP endpoint, reachable from every namespace through a
ClusterIP service, accepting traces, metrics and logs over OTLP gRPC (port 4317) and OTLP
HTTP (port 4318). It SHALL NOT be published through the ingress.

#### Scenario: Workload sends spans
- **WHEN** a pod in any namespace sends OTLP traces to
  `otel-collector.kube-tracing.svc.cluster.local:4317`
- **THEN** the spans become queryable in Grafana's Tempo datasource

#### Scenario: Workload sends metrics and logs over OTLP
- **WHEN** a pod sends OTLP metrics and OTLP logs to the same endpoint
- **THEN** the metrics are queryable in Prometheus and the logs in Loki

#### Scenario: Not reachable from outside
- **WHEN** a client outside the cluster looks for an OTLP route on the ingress
- **THEN** no ingress host or path serves the collector

### Requirement: Collector enriches signals with Kubernetes metadata
Signals passing through the collector SHALL carry the source pod's namespace, pod name,
node name and owning workload as resource attributes.

#### Scenario: Span from an annotated workload
- **WHEN** a span arrives from a pod of a Deployment in `ai-llm`
- **THEN** the stored span has `k8s.namespace.name=ai-llm` and the pod's and Deployment's
  names as resource attributes

### Requirement: Traces are retained on persistent storage
Traces SHALL be stored on a persistent volume of the cluster's storage class and kept for
a configurable retention period (default 7 days, matching Loki's log retention).

#### Scenario: Trace store pod restarts
- **WHEN** the trace store pod is deleted and recreated
- **THEN** traces ingested before the restart and within retention are still queryable

### Requirement: Trace store accepts traffic only from known peers
Trace ingest on the trace store SHALL be accepted only from the collector. Trace queries
SHALL be accepted only from the monitoring namespace (Grafana and Prometheus).

#### Scenario: Workload bypasses the collector
- **WHEN** a pod in `ai-llm` sends OTLP directly to the trace store's ingest port
- **THEN** the connection is refused by network policy

#### Scenario: Grafana queries traces
- **WHEN** Grafana queries the trace store's HTTP API
- **THEN** the query succeeds

### Requirement: Auto-instrumentation operator is available
The cluster SHALL run the OpenTelemetry Operator with its admission webhook certificate
issued by cert-manager, so that a namespace can declare an `Instrumentation` resource and
pods opt in with an `instrumentation.opentelemetry.io/inject-<language>` annotation.
Yakir SHALL NOT create any `Instrumentation` resource itself.

#### Scenario: Factory declares instrumentation
- **WHEN** an `Instrumentation` resource pointing at the collector exists in `ai-llm`, and a
  pod there carries `instrumentation.opentelemetry.io/inject-python: "true"`
- **THEN** the pod starts with the OpenTelemetry SDK injected and its spans reach the trace
  store

#### Scenario: No instrumentation declared
- **WHEN** the cluster is deployed without ai-factory
- **THEN** the `Instrumentation` CRD exists and no `Instrumentation` resource does

### Requirement: Ingress requests produce root spans
Traefik SHALL export a span for every request it routes to the collector, and SHALL
propagate W3C trace context to the backend.

#### Scenario: Request through the ingress
- **WHEN** a client requests `https://monitoring.<domain>/`
- **THEN** a Traefik span for that request is queryable in Tempo and the backend receives a
  `traceparent` header

### Requirement: Platform components emit their own spans
Argo CD, Grafana, Loki and Tempo SHALL export their own spans to the collector.

#### Scenario: Grafana query is traced
- **WHEN** a user runs a Loki query from Grafana
- **THEN** spans from both Grafana and Loki for that query are queryable in Tempo

#### Scenario: Argo CD reconcile is traced
- **WHEN** Argo CD reconciles an application
- **THEN** spans with service name for the Argo CD component are queryable in Tempo

### Requirement: Deployment is idempotent and gated on readiness
Running the playbook twice SHALL report no change on the second run for the tracing role,
and the role SHALL wait for its pods to become Ready, excluding terminal pods, before
the play continues.

#### Scenario: Replay
- **WHEN** the leader play is run a second time with unchanged inputs
- **THEN** the tracing role's tasks report `ok`, not `changed`
