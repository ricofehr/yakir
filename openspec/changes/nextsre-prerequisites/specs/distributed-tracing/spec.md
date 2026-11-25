# Spec Delta

## ADDED Requirements

### Requirement: Tempo allows query ingress from the NextSRE namespace
Tempo's NetworkPolicy SHALL permit ingress on TCP port 3200 from pods labeled with the NextSRE namespace in addition to the monitoring namespace.

#### Scenario: NextSRE traces tool queries Tempo
- **WHEN** a pod in the `nextsre` namespace sends a TraceQL or trace lookup query to `tempo.kube-tracing.svc.cluster.local:3200`
- **THEN** the request is accepted through the NetworkPolicy and receives trace data
