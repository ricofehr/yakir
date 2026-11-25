# Spec Delta

## ADDED Requirements

### Requirement: Alertmanager routes alerts to NextSRE webhook receiver
Alertmanager SHALL configure a webhook receiver named `nextsre` pointing to `http://gateway.nextsre.svc.cluster.local:9302/api/v1/alerts`.
All HTTP webhook calls to this receiver SHALL authenticate using a Bearer token read from a mounted credentials secret.

#### Scenario: Firing alert routed to NextSRE
- **WHEN** an alert matching the NextSRE route fires
- **THEN** Alertmanager sends an HTTP POST request to the NextSRE gateway URL with `Authorization: Bearer <token>` and `send_resolved: false`

### Requirement: Prometheus defines workload health alerting rules
Prometheus SHALL include alerting rules for core Kubernetes workload failures, specifically pod CrashLoopBackOff and pods failing readiness.

#### Scenario: Pod crash-looping alert fires
- **WHEN** a container in an observed namespace has restart counts increasing while in CrashLoopBackOff
- **THEN** Prometheus evaluates the alert rule to firing and sends it to Alertmanager
