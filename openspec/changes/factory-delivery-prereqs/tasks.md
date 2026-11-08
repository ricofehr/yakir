# Tasks

## 1. gitops role

- [x] 1.1 Defaults: `gitops_build_namespace` (`ai-build`) in `gitops_project_namespaces`; `gitops_apps_project`, `gitops_apps_repo_url`, `gitops_apps_namespaces`. Verify: render `app-project.yml.j2` with the defaults and find `ai-build`.
- [x] 1.2 Task creating `ai-build` at Pod Security `privileged`. Verify: ansible-lint.
- [x] 1.3 `templates/apps-project.yml.j2` and its task. Verify: render with the defaults, then a server-side dry run against the cluster.
- [x] 1.4 `templates/apps-namespaces-policy.yml.j2` and its task, before the project. Verify: render; server-side dry run; no existing `prod-*`/`review-*` namespace it would block.

- [x] 1.5 `templates/apps-hosts-policy.yml.j2` (one host per namespace, no default backend), and Traefik/Gateway API kinds denied in the project. Verify: strict server-side dry run.
- [x] 1.6 `templates/apparmor-localhost-policy.yml.j2`: no Localhost AppArmor profile outside `ai-build` and `kube-system` (fields and annotations, every container kind). Verify: strict server-side dry run.

- [x] 1.7 `templates/apps-resources-policy.yml.j2` (quota cap from `gitops_apps_quota_max`, no priority class), ResourceQuota/LimitRange allowed in `factory-apps`; `enforce-version` in the namespace policy. Verify: strict server-side dry run.

- [x] 1.8 Second review: `Role`/`RoleBinding`, `Endpoints`/`EndpointSlice`, `CertificateRequest`/`Issuer` denied in the project; Certificates not CA and ACME-only; quota unscoped and required (`apps-quota-required-policy.yml.j2`, parameterized); Services ClusterIP without external IPs; Traefik/Gateway objects refused by policy; priority by value; the profile installed only with the gitops role. Verify: strict server-side dry run; ansible-lint.

- [x] 1.9 Namespaced kinds of `factory-apps` as a whitelist (`gitops_apps_namespaced_allowed`). Verify: strict server-side dry run.

## 2. crio role

- [x] 2.1 `files/apparmor-buildkitd` and the install/check/load tasks under tag `apparmor`, loading when the file changed or the kernel lacks the profile. Verify: `apparmor_parser --skip-kernel-load` parses it on a worker; ansible-lint.

## 3. k8s role

- [x] 3.0 `kubectl proxy` bound to 127.0.0.1, restarted on unit change, tag `kubeproxy`. Verify: ansible-lint; after apply, `curl http://<manager>:8001/version` from the LAN is refused.

## 4. Docs and apply

- [x] 4.1 README: the second project, the namespace policy, the profile and its tag. Verify: present.

## Workflow follow-up

- After merge: terraform plan with no change, then `--ansible-tags apparmor,gitops,kubeproxy`. Check that the profile is loaded on every node, `factory-apps` and the policies exist, and `ai-build` enforces `privileged`.
- Then exercise the scenarios with `kubectl create --dry-run=server` (admission runs on server dry runs): a `prod-x` namespace at `privileged`, an Ingress in `prod-hello` for `gitlab.<domain>`, a `buildkitd` pod outside `ai-build`, a quota with `requests.cpu: "16"`, a Service with `externalIPs`, a pod in a namespace without quota are refused; the computed hosts are admitted. Check `kubectl get validatingadmissionpolicy -o jsonpath='{..typeChecking}'` reports no warnings.
