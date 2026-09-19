# v1.4

## Changes by Kind

### Improvement

- Replace the archived elastic/elasticsearch and elastic/kibana helm charts (stuck at 8.5.1) with Grafana Loki
- Browse cluster logs from the Grafana deployed by the monitoring role, instead of a dedicated Kibana ingress
- Provision the Prometheus datasource through the Grafana datasource sidecar, pinned to the uid the k8s dashboard references
- Read the storage class from a single global_storage_class instead of repeating it per role
- Uninstall the elasticsearch and kibana releases on upgrade, so re-runs do not leave the replaced stack running (v1.4 migration step, droppable once every cluster has been through it)

### Bug Fix

- Drop the anonymous superuser and the unverified TLS left over from the elasticsearch deployment
- Generate the log backend credentials once and store them in a secret, so replays stay idempotent
- Restrict the loki backend to its gateway with a network policy, so the basic auth cannot be bypassed from another pod (enforced by calico and cilium, inert under flannel)
