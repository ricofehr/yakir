# Proposal

## Why

NextSRE is being deployed onto the cluster to provide autonomous incident observation and remediation. To function in a real cluster environment (observe-only initially, and bounded writes later), the platform layers managed by Yakir must provide the necessary integration points:
1. Alertmanager needs a dedicated webhook receiver and bearer token authentication to route firing alerts to NextSRE's gateway.
2. Prometheus requires workload alerting rules so pod crash-loops and readiness failures are surfaced.
3. Tempo's NetworkPolicy must permit query ingress from NextSRE's `tempo-traces` component.
4. Loki's basic-auth credentials must be reflected into the `nextsre` namespace for `loki-logs`.
5. Argo CD's root AppProject and cluster admission policies must admit the `nextsre` namespace and enforce the deployment mutation boundaries for `k8s-write`.

## What Changes

- **Alertmanager Receiver & Webhook Auth**: In `ansible/roles/monitoring`, configure a `nextsre` webhook receiver routing to `http://gateway.nextsre.svc.cluster.local:9302/api/v1/alerts` authenticated with a bearer token stored in a Secret.
- **Prometheus Workload Alerts**: In `ansible/roles/monitoring`, define core Kubernetes workload alerting rules (`KubePodCrashLooping`, `KubePodNotReady`, `KubeDeploymentReplicasMismatch`) with alert label routing.
- **Tempo NetworkPolicy Opening**: In `ansible/roles/tracing`, update `tempo-networkpolicy.yml.j2` to allow port 3200 ingress from the `nextsre` namespace in addition to `kube-monitoring`.
- **Loki Credential Reflection**: In `ansible/roles/logcollect`, annotate the `loki-basic-auth` Secret with Reflector annotations (`emberstack.io/reflection-allowed: "true"`, `emberstack.io/reflection-auto-namespaces: "nextsre"`) so credentials replicate to `nextsre`.
- **Argo CD AppProject & Admission Policies**: In `ansible/roles/gitops`, add `nextsre` to the admitted destination namespaces of the `ai-factory` AppProject, and install the `nextsre-k8s-write-scope` ValidatingAdmissionPolicy and binding to bound Operator write actions.

## Capabilities

### New Capabilities
- `nextsre-platform-prereqs`: Covers cross-namespace credential reflection for Loki, namespace admission in Argo CD, and the CEL ValidatingAdmissionPolicy protecting Deployment mutations against unauthorized spec modifications.

### Modified Capabilities
- `cluster-monitoring`: Adds the NextSRE webhook receiver, bearer token authentication config, and core workload alerting rules in Prometheus.
- `distributed-tracing`: Extends Tempo's NetworkPolicy to permit query ingress on port 3200 from the `nextsre` namespace.

## Impact

- Files:
  - `ansible/roles/monitoring/tasks/main.yml`, `ansible/roles/monitoring/templates/*`
  - `ansible/roles/tracing/templates/tempo-networkpolicy.yml.j2`
  - `ansible/roles/logcollect/tasks/main.yml`
  - `ansible/roles/gitops/templates/app-project.yml.j2`, `ansible/roles/gitops/tasks/main.yml`, and admission policy templates
- Branch: `feat/nextsre-prerequisites`
