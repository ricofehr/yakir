# Proposal

## Why

ai-factory now ships GitLab (ai-factory PR #15, merged). It cannot sync until the cluster
provides what only yakir can: a namespace holding its credentials, a working Ceph bucket
StorageClass, an SSH path through HAProxy and Traefik, an off-site backup store, and an
AppProject that admits its admission policy. The same AppProject still carries the
widening the removed DNS-01 issuer needed. The gitops role still seeds OVH and GitHub App
credentials nobody uses, and Grafana has had one replica stuck for days.

## What Changes

- **GitLab's namespace and credentials** (gitops role): `ai-gitlab` joins the bootstrap
  namespaces. It holds:
  - `valkey-auth`, generated once and reused;
  - `gitlab-backup-offsite`: the off-site MinIO endpoint, a GitLab-only access key and
    secret, and a `crypt-passphrase` read from a new `--gitlab-backup-passphrase-file`.
- **Off-site backup store** (gitops role, new): on the MinIO behind `--backup-server`, using
  separate admin credentials from a new `--minio-admin-credentials-file` (kept on the
  controller, never in the cluster) and a pinned, checksum-verified `mc`, an idempotent setup
  of:
  - the `gitlab-backups` bucket, created with **object lock** (default GOVERNANCE retention
    of 90 days), with a lifecycle rule (90 days current, 30 days noncurrent);
  - a `gitlab-backup-writer` policy granting list, read and write but **no delete**;
  - a `gitlab-backup` user with that policy, whose secret is generated once, stored in
    `gitlab-backup-offsite`, and re-set on a rebuilt cluster.
- **Rook object storage** (csi role):
  - the `rook-ceph-bucket` StorageClass points at the real store, `my-store`;
  - the store allows S3 users in `ai-gitlab`;
  - the operator allows the `bucketOwner` bucket-claim field (`obcAllowAdditionalConfigFields`).
- **Git over SSH**: Traefik gains a `gitlab-shell` entrypoint (port 2222, NodePort 30022),
  and HAProxy on the managers forwards `:2222` to it.
- **AppProject envelope** (gitops role):
  - destinations: `ai-gitlab` in; **BREAKING** `kube-system`, `kube-cert` and `arc-system` out;
  - cluster-resource whitelist: `ValidatingAdmissionPolicy` and its Binding in;
    **BREAKING** `ClusterIssuer` and `APIService` out.
- **BREAKING** **PR #13 and ARC cleanup**:
  - `ai-devpods` is no longer created;
  - the OVH credential seeding and `--ovh-credentials-file` go;
  - the GitHub App secret and `--github-app-id`, `--github-app-installation-id` and
    `--github-app-key` go.
- **Argo CD polls every 60 s** (`timeout.reconciliation`).
- **Grafana runs one replica with the `Recreate` strategy**: two replicas cannot share its
  ReadWriteOnce volume.
- **`deploy-to-libvirt --ansible-tags`** passes `--tags` to ansible, so a live cluster can
  take a subset of roles. `terraform apply` stays, and does nothing on an unchanged cluster.

## Capabilities

### New Capabilities
- `factory-bootstrap`: what the gitops role hands the ai-factory: namespaces, the
  credentials it seeds, the AppProject envelope, and how fast Argo CD picks up commits.
- `offsite-backup-store`: the off-site bucket GitLab's backups are copied to, and the
  guarantee that nothing in the cluster can delete from it.
- `object-storage`: Ceph RGW buckets and S3 users for cluster workloads.
- `git-ssh-ingress`: Git over SSH from outside the cluster to the factory's GitLab.
- `deploy-tooling`: how `deploy-to-libvirt` applies changes to a cluster.
- `cluster-monitoring`: Grafana's availability.

### Modified Capabilities
- (none: `distributed-tracing` and `telemetry-correlation` are untouched)

## Impact

- Branch: `feat/gitlab-prerequisites`
- Code: `ansible/roles/gitops/{tasks,defaults,vars,templates}` (new `tasks/gitlab.yml`, and the
  bucket-policy and lifecycle templates),
  `ansible/roles/csi/{tasks/rook.yml,templates/rook-bucket.yml.j2}`,
  `ansible/roles/ingress/{tasks,defaults}`, `ansible/roles/haproxy/{templates,defaults}`,
  `ansible/group_vars/{all/global,managers/haproxy,leader/ingress}`,
  `ansible/roles/monitoring/tasks/main.yml`, `deploy-to-libvirt`, README / docs.
- Live cluster, after merge: `deploy-to-libvirt … --ansible-tags gitops,csi,ingress,haproxy,monitoring`
  (operator go-ahead). Then a one-off runbook removes what the dropped tasks leave behind:
  the `ai-devpods` and `arc-system` namespaces, and the `ovh-credentials` and
  `arc-github-app` secrets.
- the operator's deploy wrapper must stop passing the removed flags and
  gain `--gitlab-backup-passphrase-file`. That is a host change, made with the operator's
  go-ahead and recorded in the inventory.
- External: **MinIO's community server and `mc` are archived and unmaintained**: no
  security updates, and `dl.min.io` returns 410. `mc` is pinned to its last GitHub release
  by checksum. Replacing the MinIO server on the backup server is outside this change, and flagged.
