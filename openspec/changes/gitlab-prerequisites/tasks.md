# Tasks

## 1. GitLab bootstrap in the gitops role

- [x] 1.1 `gitops_app_namespaces`: add `ai-gitlab`, drop `ai-devpods`. Add the `valkey-auth` look-up/generate-once/store tasks (key `default`), following `litellm-masterkey`. Verify: `ansible-playbook --syntax-check ansible/playbook.yml` passes and the task block mirrors the existing pattern.
- [x] 1.2 Add `gitops_gitlab_backup_passphrase_file`, read and asserted non-empty on the controller, and the `gitlab-backup-offsite` secret (endpoint from `backup_s3_url`, access key `gitlab-backup`, a generated-once `secret-key`, and `crypt-passphrase`). Skip it with a debug message when no file is given. Verify: syntax check; `no_log` on every task touching it.
- [x] 1.3 Add the off-site store block (design decision 1): `templates/gitlab-backup-writer.json.j2`, `templates/gitlab-backups-lifecycle.json.j2`, the pinned `mc` download with checksum, and the idempotent `mc` steps via `MC_HOST_offsite`. Verify: run the same `mc` sequence twice against a throwaway local MinIO in `/tmp`. The second run changes nothing; one lifecycle config, not two. A delete with the GitLab key gets AccessDenied, while put/get/list succeed.
- [x] 1.4 AppProject: destinations (`ai-gitlab` in; `kube-system`, cert-manager namespace, `arc-system` out; drop `gitops_cert_namespace` and its comment), whitelist (`ValidatingAdmissionPolicy` + Binding in; `ClusterIssuer` + `APIService` out, with the comment updated). Verify: render `app-project.yml.j2` with the role defaults (jinja2) and check the lists.
- [x] 1.5 Remove the GitHub App and OVH tasks, defaults and vars. Verify: `git grep -nE 'ovh|github_app|arc-github-app|ai-devpods'` returns only history and docs about the removal.
- [x] 1.6 Argo CD `timeout.reconciliation: 60s` in `configs.cm`. Verify: the task's values contain it.

## 2. Rook

- [x] 2.1 `rook-bucket.yml.j2`: `objectStoreName: my-store`; `allowUsersInNamespaces` from `csi_rook_object_user_namespaces` (default `["ai-gitlab"]`). `rook.yml`: `obcAllowAdditionalConfigFields: "maxObjects,maxSize,bucketOwner"`. Verify: render the template and see both fields; `ansible-lint` passes.

## 3. SSH path

- [x] 3.1 `global_ingress_ssh_nodeport: 30022`, mapped in `group_vars/{leader/ingress,managers/haproxy}`, plus role defaults. Add Traefik's `gitlab-shell` port in the ingress task, the HAProxy `gitlab-ssh` frontend and backend, and a `haproxy` tag on the role. Verify: render `haproxy.cfg.j2` with sample vars, check it with `haproxy -c` if available (else a structural review), and `ansible-lint`.

## 4. Deploy script

- [x] 4.1 `deploy-to-libvirt`: remove `--github-app-*` and `--ovh-credentials-file` (flags, help, variables, pre-terraform check), and add `--gitlab-backup-passphrase-file` (readable-file check, needs `--gitops-repo`) and `--ansible-tags`. Verify: `shellcheck deploy-to-libvirt`; `--ovh-credentials-file x` exits with help before terraform; `bash -n`.

## 5. Grafana

- [x] 5.1 `replicas: 1`, `deploymentStrategy: {type: Recreate}`. Verify: the task's values; `ansible-lint`.

## 6. Docs and integration

- [x] 6.1 Update the README / docs: deploy flags, the gitops bootstrap secrets (`valkey-auth`, `gitlab-backup-offsite`), the off-site store, the SSH port, `--ansible-tags`, and the MinIO-archived note. Verify: every flag in `deploy-to-libvirt --help` is documented and no removed flag is.
- [x] 6.2 Run the full gate: `ansible-lint` (repo profile), `ansible-playbook --syntax-check`, `shellcheck deploy-to-libvirt`, `openspec validate gitlab-prerequisites --strict`. Verify: all pass.
- [x] 6.3 Prepare the PR body with the migration plan (wrapper update, tagged run, runbook, verification). Verify: the body contains them.

## Workflow follow-up

- After merge, with the operator's go-ahead: update the operator's deploy wrapper , run the tagged deploy, run the runbook, then check that ai-factory's GitLab apps go Healthy.
- CI archives the change after merge.
