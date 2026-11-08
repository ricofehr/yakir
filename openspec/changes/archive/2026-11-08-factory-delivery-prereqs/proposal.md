# Proposal

## Why

ai-factory's next change delivers the apps it builds: an ApplicationSet deploys each app of
a `factory/deployments` repository on the cluster's GitLab to `prod-<app>`, and each open
merge request to `review-<app>-<mr>`. CI builds images on a shared rootless BuildKit. Three
things only yakir can provide, so that no commit to ai-factory widens its own envelope:
- a project for those apps;
- a namespace where BuildKit may run with seccomp `Unconfined`;
- user namespaces for that one pod, on workers that restrict them.

## What Changes

- **`factory-apps` AppProject** (gitops role, new `apps-project.yml.j2`):
  - one source, the in-cluster URL of `factory/deployments`;
  - destinations `prod-*` and `review-*`;
  - no cluster-scoped object but a `Namespace` named `prod-*`/`review-*` (a review deployment
    owns its namespace); by name, since Argo CD checks destinations for namespaced objects only;
  - `Secret` and `DaemonSet` denied, like the root project; `ResourceQuota` and `LimitRange`
    allowed, since the app chart sets them and a policy caps the quota.
- **`factory-apps-namespaces` admission policy** (gitops role): every `prod-*` or `review-*`
  namespace must enforce Pod Security `baseline` or `restricted`. Without it, the
  `Namespace` whitelist would let a commit create a privileged namespace.
- **`factory-apps-hosts` admission policy** (gitops role): Ingresses and Certificates in
  `prod-<app>` / `review-<app>-<mr>` may only name `<app>.apps.<domain>` /
  `<app>-mr-<mr>.review.<domain>`; Traefik and Gateway API kinds are denied to the project.
  Otherwise an app could publish the platform's hostnames on the shared Traefik.
- **`factory-apps-resources` and `factory-apps-quota-required` admission policies** (gitops
  role): a capped, unscoped quota required before any app pod; no positive priority; plain
  ClusterIP Services only; no Traefik or Gateway API objects. The project also denies
  `Role`/`RoleBinding`, `Endpoints`/`EndpointSlice`, and cert-manager requests and issuers.
- **`localhost-apparmor-profiles` admission policy** (gitops role): only pods in `ai-build`
  may select a Localhost AppArmor profile; Pod Security baseline would otherwise admit
  `buildkitd`, or any of Ubuntu's other unconfined userns profiles, anywhere.
- **`kubectl proxy` on the loopback** (k8s role, tag `kubeproxy`): it served the API with the
  admin kubeconfig, unauthenticated, on a manager's LAN address.
- **`ai-build` namespace** (gitops role), at Pod Security `privileged`, added to the
  ai-factory project's destinations.
- **`buildkitd` AppArmor profile** (crio role, tag `apparmor`): `flags=(unconfined)` plus
  `userns`, installed and loaded on every node. Ubuntu 24.04's
  `kernel.apparmor_restrict_unprivileged_userns=1` stays on for everything else.
- README: the second project, the policy, the profile.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `factory-bootstrap`: adds the apps project, its namespace policy, the build namespace and
  the BuildKit AppArmor profile.

## Impact

- Branch: `feat/factory-delivery-prereqs`
- Code: `ansible/roles/gitops/{defaults/main.yml,tasks/main.yml}` and its templates
  `apps-project`, `apps-namespaces-policy`, `apps-hosts-policy`, `apps-resources-policy`,
  `apps-quota-required-policy`, `apparmor-localhost-policy`; `ansible/roles/k8s/tasks/{main,kubeproxy}.yml`,
  `ansible/roles/crio/{tasks/main.yml,files/apparmor-buildkitd}`, `README.md`.
- Applied to the live cluster with `--ansible-tags apparmor,gitops,kubeproxy`, after a terraform plan
  shows no change. Must land before ai-factory's delivery change merges.
- Out of scope: the delivery charts themselves (ai-factory).
