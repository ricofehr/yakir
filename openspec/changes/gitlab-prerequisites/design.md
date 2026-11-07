# Design

## Context

See proposal.md for why. Facts checked on 2026-11-07:

- The gitops role already follows two patterns: credentials generated once and reused
  (`litellm-masterkey`, `keycloak-admin`, `neo4j-auth`), and credential files read on the
  controller, never passed as values (`--github-app-key`, `--ovh-credentials-file`).
- The ai-factory AppProject comes from `templates/app-project.yml.j2`, driven by
  `gitops_project_namespaces` (defaults) and `gitops_project_cluster_resources` (vars).
  Secrets and DaemonSets are already denied as namespaced kinds.
- Rook 1.19.2 is installed by helm with only `operatorNamespace` set. The chart exposes
  `obcAllowAdditionalConfigFields` (default `"maxObjects,maxSize"`).
  `templates/rook-bucket.yml.j2` creates `CephObjectStore/my-store`, but its StorageClass
  names `objectStoreName: rook-ceph-bucket`.
- Traefik 39.0.4 (v3.6.9) is a NodePort service whose `ports` are set in
  `roles/ingress/tasks/main.yml`. HAProxy (`roles/haproxy/templates/haproxy.cfg.j2`, TCP
  mode) forwards `:80`/`:443` to the `global_ingress_{http,https}_nodeport` values.
- Grafana (chart 6.58.8) runs `replicas: 2` with persistence on one RWO PVC. The second pod
  has waited on the attach for four days (node1 vs node3).
- **MinIO community and `mc` are archived.** `dl.min.io` returns 410. `minio/mc`'s last
  GitHub release (`RELEASE.2025-08-13T08-35-41Z`) still carries binaries and `.sha256sum`
  files. The backup server runs MinIO `RELEASE.2025-09-07T16-13-09Z`, and the operator's deploy wrapper passes
  `--backup-server <backup server>` with credentials Velero uses.
- `deploy-to-libvirt` always runs `terraform apply`, then the whole playbook. Roles carry
  tags (`gitops`, `csi`, `ingress`, `monitoring`; `haproxy` only under `controlplane`).

## Goals / Non-Goals

**Goals:** the specs in this change.

**Non-Goals:**
- Replacing the archived MinIO server on the backup server.
- Velero's own bucket and user.
- Keycloak realm-as-code.
- Changing ai-factory.

## Decisions

**1. Off-site store with `mc`, in the gitops role, on the controller.**
- A `block` delegated to `localhost` downloads `mc` from the pinned GitHub release URL into
  a temp dir with `get_url` and `checksum: sha256:01f866e9…`, linux-amd64. The controller is
  the server running the deploy; any other platform fails with a clear message.
- **Admin credentials come from `--minio-admin-credentials-file`**, a yaml file on the
  controller, never the `--backup-*` keys. Those also sit in Velero's in-cluster Secret, and
  an admin key there would let a cluster compromise delete the backups meant to survive it.
- Credentials reach `mc` through a 0600 `config.json` in a private temporary directory. They
  never go through the environment, which Ansible puts on the command line it runs (visible
  in `ps` and at `-vvv`), nor through `MC_HOST_*`, whose keys `mc` does not URL-decode. The
  GitLab user's secret is fed to `mc admin user add` on stdin.
- `mc admin info offsite` runs first. `mc` treats an alias it cannot resolve as a local path,
  and would otherwise create directories on the controller.
- A `uname -sm` check fails early on a controller other than Linux x86_64.
- `no_log` sits only on the tasks that hold secrets, so assertion and `mc` errors stay
  readable.
- The steps are idempotent:
  - `mc mb --ignore-existing --with-lock`, then a check that the bucket really has object
    lock (it can only be chosen at creation);
  - `mc retention set --default GOVERNANCE <retention>d`: an overwritten archive stays locked,
    so the GitLab key cannot purge backups through overwrite plus noncurrent expiry;
  - `mc ilm import` from a JSON file, which replaces the configuration (`ilm rule add` would
    stack duplicates on every replay);
  - `mc admin policy create` from a JSON file, which creates or updates;
  - `mc admin user add`, which creates or re-sets the secret;
  - `mc admin policy attach`, only when `mc admin policy entities` does not list it yet.
- The policy (`templates/gitlab-backup-writer.json.j2`) allows `s3:ListBucket` and
  `s3:GetBucketLocation` on the bucket, and `s3:GetObject`, `s3:PutObject`,
  `s3:AbortMultipartUpload` and `s3:ListMultipartUploadParts` on its objects. There is no
  `DeleteObject` and no bucket-configuration action. Combined with versioning, even a leaked
  GitLab key can only add versions.
- Lifecycle: `templates/gitlab-backups-lifecycle.json.j2` expires current objects after
  `gitops_gitlab_backup_retention_days` (90) and noncurrent versions after
  `gitops_gitlab_backup_noncurrent_days` (30).
- The user's secret follows the "generated once, then reused" pattern from
  `gitlab-backup-offsite`'s `secret-key`. A rebuilt cluster generates a new one, and
  `user add` re-sets it on MinIO, so nothing is manual.
- The role runs this only when `backup_s3_url` and its keys are set, the same condition the
  backup role uses. Without them, ai-factory's mirror cannot run, and the run says so.

Rejected:
- The `minio` Python client in a controller venv: it is equally archived, and adds a
  dependency tree.
- A manual runbook: the user chose automation.

**2. Passphrase from a file.** `--gitlab-backup-passphrase-file <path>` →
`gitops_gitlab_backup_passphrase_file`, read with `lookup('file')` like the other credential
files, checked non-empty. Without it, `gitlab-backup-offsite` is not written, and a debug
message names the consequence: the backup mirror's pods wait on the missing Secret.

**3. Namespaces and envelope.**
- `gitops_app_namespaces`: `ai-gitlab` in, `ai-devpods` out.
- `gitops_project_namespaces`: drop `kube-system`, `gitops_cert_namespace` and `arc-system`,
  along with the long comment that justified them. `gitops_cert_namespace` goes too.
- `gitops_project_cluster_resources`: `ValidatingAdmissionPolicy` and
  `ValidatingAdmissionPolicyBinding` in; `ClusterIssuer` and `APIService` out.
- Argo CD prunes the factory's own resources but not namespaces it never created through an
  Application. `ai-devpods` and `arc-system` are therefore removed by the runbook.

**4. Retired credentials.** Remove the GitHub App and OVH tasks, their defaults and vars
(`gitops_github_app_*`, `gitops_ovh_*`), their `deploy-to-libvirt` flags and help, and the
pre-terraform OVH file check. Unknown flags already make the script's argument loop exit with
help, so old wrapper invocations fail early instead of silently half-deploying.

**4a. Merge order.** ai-factory's ARC removal (PR #15) is merged and synced: no Application
targets `arc-system` any more, so this AppProject can drop it. Its GitLab Applications
(`ai-gitlab`, the admission policy) are refused until this change is applied. They recover by
themselves after the tagged run.

**5. Rook.** `rook-bucket.yml.j2`: `objectStoreName: my-store`, and
`spec.allowUsersInNamespaces` from a new `csi_rook_object_user_namespaces` (default
`["ai-gitlab"]`). `rook.yml`'s helm values gain `obcAllowAdditionalConfigFields:
"maxObjects,maxSize,bucketOwner"`. That is cluster-wide, accepted in ai-factory's design:
only the AppProject creates claims.

**6. SSH path.**
- `global_ingress_ssh_nodeport: 30022` in `group_vars/all/global`, mapped to
  `ingress_ssh_port` and `haproxy_ssh_fw_port`.
- Traefik's `ports` gain `gitlab-shell: {port: 2222, expose: {default: true}, exposedPort:
  2222, nodePort: 30022, protocol: TCP}`.
- HAProxy gains `frontend gitlab-ssh` binding `*:2222`, with a backend to `haproxy_ip:30022`.
  The managers' sshd stays on 22.

**7. Argo CD polling.** `configs.cm.timeout.reconciliation: 60s` in the existing helm values.

**8. Grafana.** `replicas: 1` and `deploymentStrategy: {type: Recreate}` in
`roles/monitoring/tasks/main.yml`.

**9. `--ansible-tags`.** `deploy-to-libvirt` collects it into `ANSIBLE_TAGS`, then appends
`--tags "$ANSIBLE_TAGS"` to the `ansible-playbook` call when set. HAProxy's role carries only
the `controlplane` tag, so it also gets `haproxy`. That lets the live run name it without
replaying the whole control plane.

## Risks / Trade-offs

- [`mc` is unmaintained] → It is pinned by checksum, runs only on the controller, and only
  against our own MinIO. The archived MinIO server is the larger exposure; flagged
  separately.
- [The `--backup-*` key may not be a MinIO admin] → `mc admin` then fails with
  AccessDenied, and the run stops with that message. Nothing is half-configured: bucket
  steps come first, user steps last.
- [The lifecycle rule expires backups of a cluster that stays down past 90 days] →
  Documented in ai-factory's `docs/gitlab.md`, and the days are variables.
- [Dropping `kube-system` / `kube-cert` from the project while live objects were applied
  there] → The cert-dns01 resources were deleted by hand after PR #13, and nothing else
  targets them. Argo CD reports no "not permitted" on the live apps (checked during apply).
- [HAProxy restart on the managers] → The role's handler restarts HAProxy on each manager.
  In-flight connections on the VIP holder drop once. That is acceptable for a maintenance
  run; retries recover.
- [The bucket StorageClass's parameters are immutable] → The csi role deletes a
  `rook-ceph-bucket` StorageClass that names the wrong store before re-creating it. No claim
  can be bound to the old one, since its store never existed.

## Migration Plan

1. Merge.
2. Update the operator's deploy wrapper: drop `--github-app-*` and `--ovh-credentials-file`, add
   `--gitlab-backup-passphrase-file <path>` and `--ansible-tags …` (operator go-ahead;
   recorded in the inventory). The passphrase file is created by the operator and stored
   in their password manager.
3. Run `deploy-to-libvirt … --ansible-tags gitops,csi,ingress,haproxy,monitoring`.
4. Runbook:

   ```sh
   kubectl delete ns ai-devpods arc-system
   kubectl delete crd -l app.kubernetes.io/part-of=gha-rs-controller --ignore-not-found
   kubectl get crd | awk '/actions.github.com/ {print $1}' | xargs -r kubectl delete crd
   kubectl -n kube-cert delete secret ovh-credentials
   kubectl -n ai-runners delete secret arc-github-app --ignore-not-found
   ```

5. Verify: `ai-gitlab` secrets present; `kubectl get sc rook-ceph-bucket -o yaml` names
   `my-store`; ai-factory's `gitlab-storage` claims bind; `nc -vz <VIP> 2222` connects; a
   delete with the GitLab key is refused; Grafana 1/1; Argo CD's `gitlab` app goes Healthy.

Rollback: revert and re-run with the same tags. The MinIO bucket, user and policy stay;
they are harmless.
