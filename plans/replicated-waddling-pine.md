# Replace the ELK stack in `logcollect` with Grafana Loki

## Context

`ansible/roles/logcollect` deploys `elastic/elasticsearch` + `elastic/kibana` from
`https://helm.elastic.co`, pinned at **8.5.1** via `global_elastic_version`. That pin is
not a conservative choice — **8.5.1 is the last version those charts were ever published
at**. Elastic archived the standalone `elasticsearch`/`kibana` charts in favour of the ECK
operator, so the repo cannot move forward on that path. It is the one component in the
README table years behind everything else (Kubernetes 1.35.2, cert-manager v1.19.4, Rook
v1.19.2 …), and it will never receive another CVE fix.

Two further problems in the current role, both visible in
`ansible/roles/logcollect/tasks/main.yml`:

- Elasticsearch is deployed with `xpack.security.enabled: true` but also
  `anonymous: { username: anonymous, roles: superuser }` — security is nominally on and
  then handed a superuser to anyone who asks.
- Fluent Bit ships `tls On` together with `tls.verify Off`, so the transport is encrypted
  against nobody in particular.

The replacement is **Grafana Loki** (AGPLv3, genuinely OSS) in single-binary mode, queried
from the **Grafana already deployed by the `monitoring` role**. Loki indexes labels rather
than full log content, so it is far lighter than any Elasticsearch-family store on the
same node budget, and it removes a second UI (Kibana) that duplicated a dashboard the
cluster already runs.

Outcome: `logcollect` becomes Fluent Bit → Loki → the existing Grafana, on maintained
charts, with a generated credential instead of an anonymous superuser.

## Design decisions

**Loki topology.** `deploymentMode: SingleBinary` with `replication_factor: 1` and
`storage.type: filesystem`, persisted on `rook-ceph-block`. The `logcollect` role only runs
`when: global_cluster_sizing == "large"`, and the simple-scalable default (3 write + 3 read
+ 3 backend + caches) is heavy for a lab cluster that also runs Rook, Prometheus and
Grafana. Single-binary is the chart's documented mode for this size.

**Auth.** Loki itself has no authentication; the chart's nginx `gateway` provides HTTP
basic auth. The credential is generated **once** and stored in a Secret:

- Do **not** use `gateway.basicAuth.username`/`password` — the chart renders the htpasswd
  through sprig's `htpasswd`, which picks a **fresh bcrypt salt on every render**. The
  generated Secret would therefore change on every playbook run and restart the gateway,
  breaking the idempotence contract in `CLAUDE.md`.
- Instead use `gateway.basicAuth.existingSecret`, pointing at a Secret this role creates.
  Verified against the chart: `templates/gateway/secret-gateway.yaml` is skipped when
  `existingSecret` is set, and `deployment-gateway-nginx.yaml` mounts it at
  `/etc/nginx/secrets`, expecting a `.htpasswd` key.

**Why no TLS inside the cluster.** The Kibana ingress disappears, so nothing in this stack
is exposed outside the cluster any more — Loki is reachable only via its ClusterIP gateway.
That is what actually retires the `tls.verify Off` problem; adding cert-manager certs for
pod-to-pod traffic would be new scope, not a fix.

**Grafana wiring — and one required change to `monitoring`.** The Loki datasource is
delivered as a Secret picked up by Grafana's datasource sidecar (the same mechanism
`roles/monitoring/templates/grafana-k8s-dashboard.yml.j2` already uses for dashboards). A
Secret, not a ConfigMap, because it carries the basic-auth password; the sidecar's default
`resource: both` covers Secrets.

Enabling that sidecar forces a second change. Verified by rendering the chart: with
`sidecar.datasources.enabled`, Grafana mounts an emptyDir over the **whole**
`/etc/grafana/provisioning/datasources` directory, while the chart's inline `datasources:`
value mounts `datasources.yaml` as a `subPath` **inside** that same directory — and the
directory mount is emitted *after* the file mount. Rather than depend on kubelet's mount
ordering, the existing **Prometheus datasource moves out of the inline `datasources:` value
and into its own sidecar ConfigMap**. Re-rendered and confirmed: that leaves exactly one
mount on the path. This mirrors the dashboard pattern already in the role.

**Fluent Bit stays at chart 0.56.0 (app v4.2.3).** It is current and not part of the
deprecation problem. Bumping it to 0.58.2 / app 5.1.2 in the same change would make any
failure hard to attribute. Its inputs, `kubernetes` filter and `cri` parser are unchanged —
only the two `es` outputs become `loki` outputs.

## Files to change

**Versions**
- `ansible/group_vars/all/global` — drop `global_elastic_version`, add
  `global_loki_version: "7.3.0"` (chart 7.3.0 → Loki **3.6.12**, confirmed from `Chart.yaml`).

**`ansible/roles/logcollect/`**
- `vars/main.yml` — replace `logcollect_elastic_repo` with
  `logcollect_loki_repo: "https://grafana.github.io/helm-charts"`; keep the Fluent Bit repo.
- `defaults/main.yml` — drop `logcollect_kibana_domain`, `logcollect_cert_issuer`,
  `logcollect_elasticsearch_version`, `logcollect_kibana_version`. Add `logcollect_loki_version`,
  `logcollect_loki_retention`, `logcollect_loki_storage_size`, `logcollect_loki_storage_class`,
  `logcollect_basic_auth_secret`, `logcollect_basic_auth_username`, `logcollect_grafana_namespace`.
- `tasks/main.yml` — rewritten:
  1. Create the namespace (unchanged).
  2. `kubernetes.core.k8s_info` — look for the existing basic-auth Secret.
  3. When absent: generate a 32-char password via `community.general.random_string`
     (collection already pinned), hash it with `openssl passwd -apr1` (nginx-compatible;
     `changed_when: false`, `no_log: true`), and create the Secret holding `username`,
     `password` and `.htpasswd`.
  4. `set_fact` the password from either branch — this is what makes re-runs idempotent.
  5. Add the Grafana chart repo; deploy `grafana/loki` with the values below.
  6. Wait for pods ready (keep the existing `kubectl wait` task shape).
  7. Create the Loki datasource Secret in `logcollect_grafana_namespace` from a template.
  8. Deploy Fluent Bit with `loki` outputs.
- `templates/loki-datasource.yml.j2` — **new**. Secret labelled `grafana_datasource: "1"`,
  `stringData.loki-datasource.yaml` holding a provisioning doc with `basicAuth: true`,
  `basicAuthUser`, and `secureJsonData.basicAuthPassword`.

**`ansible/roles/monitoring/`**
- `tasks/main.yml` — add `sidecar.datasources.enabled: true` / `label: grafana_datasource`;
  remove the inline `datasources:` block; add a task deploying the new template.
- `templates/prometheus-datasource.yml.j2` — **new**. Same Prometheus datasource, as a
  sidecar-discovered ConfigMap in `monitoring_namespace`.

**`ansible/group_vars/leader/logcollect`** — retarget to the new variable names.

**Docs**
- `README.md` — component table: drop the `Elastic v8.5.1` row, add `Loki v3.6.12`; update
  the `logcollect` role description (line ~45) to say Loki + Fluent Bit, and note that logs
  are read from the Grafana deployed by `monitoring`.
- `CHANGELOG/CHANGELOG-1.4.md` — new `v1.4` entry under `### Improvement`.

## Loki values (rendered and verified locally with `helm template`)

```yaml
deploymentMode: SingleBinary
loki:
  auth_enabled: false
  commonConfig: { replication_factor: 1 }
  storage: { type: filesystem }
  schemaConfig:
    configs:
      - from: "2024-04-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index: { prefix: index_, period: 24h }
  limits_config: { retention_period: "{{ logcollect_loki_retention }}" }
  compactor: { retention_enabled: true, delete_request_store: filesystem }
singleBinary:
  replicas: 1
  persistence:
    enabled: "{{ logcollect_persistence_disk }}"
    size: "{{ logcollect_loki_storage_size }}"
    storageClass: "{{ logcollect_loki_storage_class }}"
write:  { replicas: 0 }
read:   { replicas: 0 }
backend: { replicas: 0 }
chunksCache:  { enabled: false }
resultsCache: { enabled: false }
lokiCanary:   { enabled: false }
test:         { enabled: false }
gateway:
  enabled: true
  replicas: 1
  basicAuth:
    enabled: true
    existingSecret: "{{ logcollect_basic_auth_secret }}"
```

`retention_period` + the compactor are deliberate: the old ES install had no retention and
would fill its PVC. Gateway service is `loki-gateway` on **port 80** (confirmed in the
rendered Service).

## Fluent Bit output

Credentials reach Fluent Bit as env vars from the same Secret (`env:` with `secretKeyRef`),
referenced as `${LOKI_USERNAME}` / `${LOKI_PASSWORD}` in classic config. Two outputs, so
systemd records — which carry no `kubernetes` field — get their own labels:

```
[OUTPUT]
    Name        loki
    Match       kube.*
    Host        loki-gateway.{{ logcollect_namespace }}.svc.cluster.local
    Port        80
    http_user   ${LOKI_USERNAME}
    http_passwd ${LOKI_PASSWORD}
    labels      job=fluentbit, $kubernetes['namespace_name'], $kubernetes['pod_name'], $kubernetes['container_name']
    Retry_Limit False

[OUTPUT]
    Name        loki
    Match       host.*
    ... labels job=systemd, node=${NODE_NAME}
```

Inputs, the `kubernetes` filter and the custom `cri` parser are carried over verbatim.

## Verification

1. `cd ansible && ansible-galaxy collection install -r requirements.yml -p ./collections`
2. `cd ansible && ansible-lint` — must be clean at `profile: production`. Run it **from
   `ansible/`**, per `CLAUDE.md`.
3. `helm template` both charts in the scratchpad using the exact values the role passes, and
   assert: gateway mounts `existingSecret`; no chart-generated gateway Secret; the
   single-binary StatefulSet claims `rook-ceph-block`; Grafana has exactly one mount on
   `/etc/grafana/provisioning/datasources`.
4. `python3 -c "import yaml, sys; yaml.safe_load(...)"` over the two new `.j2` templates
   rendered with representative values, to catch indentation errors in the embedded
   provisioning YAML.
5. `shellcheck up deploy-to-libvirt` — unchanged, but cheap and must stay clean.
6. **No cluster apply.** `CLAUDE.md` forbids running `./up` / `./deploy-to-libvirt`; a live
   `large` deployment is the human's call.

## Note

`README.md` carries a **Human Code** badge, and `CLAUDE.md` flags that agent-written changes
conflict with it. This change is agent-written. Flagging it — I will not touch the badge
either way; that is your call.
