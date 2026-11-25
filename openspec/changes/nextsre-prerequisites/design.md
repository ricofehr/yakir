# Design

## Context

See `proposal.md` for the motivation. NextSRE split architecture requires read-only query capabilities across Prometheus, Alertmanager, Loki, and Tempo, plus bounded write capabilities when the Operator is active.

## Goals / Non-Goals

**Goals:**
- Provide all cluster-side observability, security, and GitOps entry points for NextSRE through Yakir's Ansible automation.
- Ensure strict least-privilege boundary: NextSRE only reaches permitted endpoints, and writes cannot alter pod templates beyond scaling and restart annotations.

**Non-Goals:**
- Deploying NextSRE application pods (managed in `ai-factory`).
- Provisioning LLM gateway API keys (managed in `ai-factory` / LiteLLM).

## Decisions

### 1. Secret reflection via Reflector
- **Decision**: Annotate `loki-basic-auth` in `kube-logcollect` with `emberstack.io/reflection-allowed: "true"` and `emberstack.io/reflection-auto-namespaces: "nextsre"`.
- **Rationale**: Reflector is already active on the cluster (deployed by the `reflector` role) and used for pull secrets. Adding reflection annotations keeps secrets synced natively without maintaining ad-hoc Ansible copy tasks.
- **Alternative**: Manual copy or templating the secret in both namespaces, which risks drift.

### 2. Alertmanager webhook authentication via mounted secret
- **Decision**: Alertmanager mounts secret `alertmanager-nextsre-token` and references it with `credentials_file: /etc/alertmanager/secrets/nextsre/token` in the webhook config.
- **Rationale**: Keeps the bearer token out of plain-text configmaps and environment variables. The same secret value is passed to the NextSRE gateway.

### 3. CEL ValidatingAdmissionPolicy for Deployment write scope
- **Decision**: Install `nextsre-k8s-write-scope` policy and binding via `roles/gitops`.
- **Rationale**: Kubernetes RBAC can only constrain actions to resource/verb (e.g. `patch` on `deployments`), not field-level updates. CEL validation guarantees that even if the `k8s-write` ServiceAccount token is abused, container images, commands, and environment variables cannot be modified.

### 4. Tempo NetworkPolicy expansion
- **Decision**: Update `tempo-networkpolicy.yml.j2` to accept port 3200 ingress from `namespaceSelector` matching `nextsre`.
- **Rationale**: Tempo currently denies any port 3200 query not coming from `kube-monitoring`.

## Risks / Trade-offs

- [NextSRE not yet deployed when Alertmanager fires an alert] → Alertmanager retries webhook delivery with exponential backoff and logs a warning; it does not impact core alerting.
- [Admission policy rejects valid patch] → Policy specifically checks that old and new pod template specs match identically, only allowing `sre-agent/restartedAt` in annotations and `spec.replicas`.
