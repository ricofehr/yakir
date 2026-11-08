# Spec Delta

## Purpose

Defines what yakir's gitops role hands the ai-factory: the namespaces it pre-creates, the
credentials it seeds there, the envelope Argo CD may apply into, and how soon a commit lands.

## ADDED Requirements

### Requirement: The factory's apps have their own narrow project
The gitops role SHALL create a `factory-apps` AppProject whose only source is the in-cluster
URL of `factory/deployments`, whose destinations are `prod-*` and `review-*`, whose only
cluster-scoped objects are Namespaces named `prod-*` or `review-*`, and whose namespaced kinds
are a whitelist of what the app chart renders.

#### Scenario: Rendering the project
- **WHEN** `apps-project.yml.j2` is rendered with the role's defaults
- **THEN** the source, destinations, whitelist and blacklist match the requirement, and the API server accepts it in a strict server-side dry run with the whitelist's `name` fields kept

#### Scenario: A commit renders another namespace
- **WHEN** a deployments commit renders `Namespace ai-runners`
- **THEN** Argo CD refuses it as outside the project's cluster-resource whitelist

### Requirement: Factory app namespaces enforce Pod Security baseline
The gitops role SHALL install an admission policy that refuses to create or update a
`prod-*` or `review-*` namespace unless its `pod-security.kubernetes.io/enforce` label is
`baseline` or `restricted`, its `enforce-version` label absent or `latest`, and its
`factory.nextdeploy.io/app-namespace` label `true`.

#### Scenario: A commit asks for a privileged namespace
- **WHEN** anyone, Argo CD included, creates `prod-x` labelled `pod-security.kubernetes.io/enforce: privileged`
- **THEN** the API server refuses it

#### Scenario: A delivery namespace
- **WHEN** Argo CD creates `prod-hello` or `review-hello-3` labelled `baseline`
- **THEN** it is admitted

### Requirement: The factory has a build namespace
The gitops role SHALL create `ai-build` at Pod Security `privileged`, and SHALL list it
among the ai-factory project's destinations. It SHALL be the only namespace the role creates
for the factory above `baseline`.

#### Scenario: Rendering the root project
- **WHEN** `app-project.yml.j2` is rendered with the role's defaults
- **THEN** `ai-build` is a destination

### Requirement: Rootless BuildKit may create user namespaces
The crio role SHALL install and load an AppArmor profile `buildkitd` on every node, which
grants user namespaces and nothing else, under its own `apparmor` tag. The kernel's
restriction on unprivileged user namespaces SHALL stay enabled.

#### Scenario: Live cluster
- **WHEN** the playbook runs with `--ansible-tags apparmor` on a running cluster
- **THEN** every node has `buildkitd` loaded, and `kernel.apparmor_restrict_unprivileged_userns` is still 1

#### Scenario: Replay
- **WHEN** it runs again
- **THEN** nothing changes

### Requirement: Factory app hostnames are fixed per namespace
The gitops role SHALL install an admission policy that refuses, in `prod-<app>`, any Ingress
or Certificate naming another host than `<app>.apps.<domain>`, and in `review-<app>-<mr>`
any other than `<app>-mr-<mr>.review.<domain>`, any Ingress with a default backend, and any
Certificate that is a CA or names an issuer other than the ACME ClusterIssuers.

#### Scenario: An app claims a platform host
- **WHEN** an Ingress in `prod-hello` names `gitlab.<domain>`
- **THEN** the API server refuses it

#### Scenario: The computed host
- **WHEN** an Ingress in `review-hello-3` names `hello-mr-3.review.<domain>`
- **THEN** it is admitted

### Requirement: Only the build namespace may use Localhost AppArmor profiles
The gitops role SHALL install an admission policy that refuses any pod outside the build
namespace and `kube-system` selecting a Localhost AppArmor profile (`buildkitd` or any other),
by field or by annotation, in any of its containers.

#### Scenario: A pod elsewhere asks for it
- **WHEN** a pod in `prod-hello` sets `appArmorProfile: {type: Localhost, localhostProfile: buildkitd}`
- **THEN** the API server refuses it

### Requirement: Factory app namespaces are bounded
The gitops role SHALL install admission policies that refuse, in `prod-*` and `review-*`: a
ResourceQuota granting more than `gitops_apps_quota_max`, any other resource, or scoped; a
pod with a positive priority; a Service other than ClusterIP or with external IPs; any
Traefik or Gateway API object; and any new pod while the namespace has no labelled,
unscoped quota bounding CPU, memory and pods.

#### Scenario: An app raises its quota
- **WHEN** a ResourceQuota in `prod-hello` sets `requests.cpu: "16"`
- **THEN** the API server refuses it

#### Scenario: The quota is dropped
- **WHEN** an app namespace has no `factory.nextdeploy.io/app-quota` ResourceQuota
- **THEN** no new pod is admitted there

#### Scenario: A Service asks for external IPs
- **WHEN** a Service in `prod-hello` sets `externalIPs`
- **THEN** the API server refuses it

### Requirement: The API proxy is not on the network
The k8s role SHALL run `kubectl proxy` on the managers bound to the loopback only, and SHALL
restart it when its unit changes.

#### Scenario: A LAN client calls the proxy port
- **WHEN** a host on the LAN requests `http://<manager>:8001/version`
- **THEN** the connection is refused
