# AI Software Factory on the Yakir cluster

## Context

The goal is an **AI software factory** — an operating model where the SDLC runs as a
production line with agents doing the work at each stage — built on the Kubernetes cluster
`yakir` provisions, deployed to **ricosrv (192.168.3.42)**. The reference is Uber's
platform (Port newsletter): six foundational components — context graph, skills registry,
MCP gateway, LLM gateway, warm agent environments, assistant interface — with the workflows
layered on top. The article's central claim is that *the platform has to exist before any
of the workflows*, because every workflow leans on several pieces at once. That ordering is
what this plan follows.

`yakir`'s stated contract is "a base k8s install" — 17 roles, all cluster plumbing. The
factory is an application layer. Per your decision it stays out of `yakir`, which gains
exactly **one** role (`gitops`) and hands off to a new **`ai-factory`** repo that Argo CD
reconciles. This also closes yakir's own README TODO ("Add Gitops tools") and means factory
changes ship by `git push` rather than by re-running a playbook against a live cluster.

### Live findings from probing the lab (2026-09-22)

These are facts from this session, not assumptions:

1. **ricosrv is down.** No ping, no SSH on 192.168.3.42; `nexus.nextdeploy.io` is down with
   it. Nothing deploys until it is back. Per your answer we build anyway — `CLAUDE.md`
   forbids me running `./deploy-to-libvirt`, so the apply was always yours.
2. **ricostation's firewall blocks the cluster from the LLM.** `ufw` allows `8080/tcp` only
   from `192.168.2.0/24`. The k8s VMs live on `192.168.3.210-224`. **As things stand the
   LLM gateway cannot reach the local model at all.** Needs an operator fix (below).
3. **The local model is live and bigger than the inventory says.** `qwen3-next-instruct`
   (Qwen3-Next-80B-A3B Q4_K_M) is serving, and `LLAMA_CTX` is now **65536**, not the 32K in
   `inventory.md`. VRAM 15.5/15.9 GiB.
4. **The model server is a 2-slot, unauthenticated endpoint.** `LLAMA_EXTRA=--metrics
   --parallel 2 --kv-unified`, no `--api-key`. Both facts constrain the gateway config.
5. The **Human Code badge is already gone** (commit `95e4788`). `CLAUDE.md`'s note about it
   is stale; no provenance conflict remains. Worth deleting that note.

## Decisions

**Local-only LLM gateway.** Per your answer, LiteLLM fronts **only** the Qwen3 on
ricostation. No Anthropic API key, no cloud spend. Claude Code keeps using your
subscription directly inside DevPods and runners. The gateway is still worth having: it
gives one OpenAI-compatible endpoint, virtual keys per project, budgets, retries, and
Prometheus metrics into the Grafana `monitoring` already deploys — and adding a second
backend later is a values-file edit.

**Secrets are created at bootstrap, not stored in git.** I floated External Secrets in the
question; I am walking that back. ESO needs a backing store, and the only OSS candidate
here (OpenBao) brings a manual-unseal problem that is genuinely annoying in a home lab.
Instead the `gitops` role creates the handful of Secrets (LiteLLM master key, llama API key,
GitHub App credentials, Argo CD repo key) from `-e` extra-vars — **exactly the idiom
`roles/backup` already uses** for `backup_s3_accesskey_secret`. Argo CD apps reference them
by name. Zero new infra, no secrets in the GitOps repo. OpenBao + ESO is the documented
upgrade path when rotation actually matters.

**Component picks**, all verified against live registries today:

| Block | Choice | Chart / version |
|---|---|---|
| GitOps | Argo CD | `argo/argo-cd` 10.9.2 (app v3.5.3) |
| Database | CloudNativePG | `cnpg/cloudnative-pg` 0.29.0 (app 1.30.0) |
| SSO | Keycloak | `codecentric/keycloakx` 7.3.2 (app 26.7.4) |
| LLM gateway | LiteLLM | `oci://ghcr.io/berriai/litellm-helm` 1.102.0 |
| MCP gateway | ToolHive operator | `toolhive/toolhive-operator` 0.5.28 (app v0.8.1) + CRDs 0.0.106 |
| CI runners | ARC scale sets | `oci://ghcr.io/actions/actions-runner-controller-charts/*` 0.14.2 |
| DevPods | Coder | `coder/coder` 2.37.2 |
| Context graph | Neo4j + Graphiti MCP | `neo4j/neo4j` 2026.9.0 |
| Assistant | Open WebUI | `openwebui/open-webui` 16.6.0 (app 0.11.4) |

ToolHive over IBM ContextForge: it is a real Kubernetes operator
(`MCPServer`/`MCPExternalAuthConfig` CRDs under `toolhive.stacklok.dev/v1alpha1`, verified),
so MCP servers become declarative objects Argo CD can reconcile like anything else.

**One Postgres, many databases.** A single CNPG `Cluster` (`factory-pg`) with CNPG's
`Database` CRs for litellm / keycloak / coder / openwebui, rather than four clusters.

## Delivery — 4 MRs, dependency-ordered

All blocks get implemented in this session so the context isn't lost, but they land as four
reviewable MRs. MR1 is the only one that touches `yakir`.

### MR1 — Foundation *(repo: `yakir` + new `ai-factory` skeleton)*

The `gitops` role follows the `ingress`/`monitoring` shape exactly: namespace →
`kubernetes.core.helm_repository` → `kubernetes.core.helm` → `kubectl wait` readiness.

- `ansible/roles/gitops/{defaults,tasks}/main.yml` and
  `templates/root-application.yml.j2` — Argo CD + CNPG operator, repo-credential Secret
  (`no_log: true`), and the app-of-apps `Application` pointing at `ai-factory/apps/`.
- `ansible/group_vars/leader/gitops`, `ansible/group_vars/all/global` — add
  `global_argocd_version`, `global_cnpg_version`.
- `ansible/playbook.yml` — 4th play, after `bench`:
  `when: gitops_repo_url != ""`, tags `["cluster", "gitops"]`. Mirrors the `backup` role's
  secret-gated conditional so a plain `./up` is unchanged.
- `up`, `deploy-to-libvirt` — `--gitops-repo`, `--gitops-branch`, `--gitops-ssh-key`.
- `tf/libvirt/terraform.tfvars.dist` — `yakir_vm_wrk_ram` **8192 → 12288** (capacity below).
- `README.md` component table + role list + a GitOps section; `CHANGELOG/CHANGELOG-1.5.md`.
- Drop the stale Human Code paragraph from `CLAUDE.md`.

`ai-factory/` (created locally at `~/Work/git/ai-factory`; **I will ask before
`gh repo create`**):

```
apps/            one Argo CD Application per block
charts/          local wrapper charts where upstream needs glue
values/          per-app values
docs/
.github/workflows/ci.yml   yamllint + helm template + kubeconform
```

MR1 ships `charts/factory-pg/` (CNPG `Cluster` + `Database` CRs) and `values/keycloak.yaml`.

### MR2 — Gateways

- **LiteLLM** — `qwen3-next-instruct` routed to `http://192.168.3.30:8080/v1` as an
  `openai/` provider. Three settings come straight from finding #3/#4:
  `max_parallel_requests: 2` (matches `--parallel 2` — more just queues),
  `max_input_tokens: 65536`, and a request timeout sized for ~30 tok/s generation.
  Postgres from `factory-pg`, master key from the bootstrap Secret, Traefik ingress +
  cert-manager on `llm.{{ global_domain }}`, Prometheus metrics.
- `charts/llm-gateway-extras/` — a Grafana dashboard ConfigMap labelled
  `grafana_dashboard: "1"`, which the `monitoring` role's sidecar already discovers. Spend
  and latency land in the Grafana you have; no second observability stack.
- **ToolHive** — operator + CRDs, then `MCPServer` CRs for github, kubernetes, fetch and a
  repo-cache filesystem server.

### MR3 — Execution

- **ARC** — controller + a `yakir-arc` scale set, `containerMode: kubernetes` with work
  volumes on `rook-ceph-block`, ephemeral runners, GitHub App credentials from the
  bootstrap Secret. Note: `ricofehr` is a personal account, so the scale set is
  repo/user-scoped, not org-scoped.
- **Coder** — Postgres from `factory-pg`, OIDC from Keycloak, wildcard ingress
  `*.devpods.{{ global_domain }}`.
- `charts/devpods-templates/` — a Coder Terraform template for a Claude Code workspace
  (git, gh, claude-code, ansible, terraform, python, plus the skills marketplace mounted),
  workspace PVC on `rook-ceph-block`.
- `charts/repo-cache/` — CronJob mirroring the `ricofehr` repos into a shared PVC. This is
  the cheap version of Uber's balloon pods: workspaces start against a warm mirror instead
  of cloning cold.

### MR4 — Knowledge & interface

- **Skills registry** — a new `ricofehr/skills` repo in **Claude Code plugin-marketplace
  format** (`.claude-plugin/marketplace.json`), which is the native distribution mechanism
  and means no invented protocol. Seeded with your four existing skills (`new-task`,
  `post-impl-check`, `push-pr`, `draft-docs-notion`) plus new ones for the stacks you named:
  `terraform-module`, `ansible-role`, `python-package`, `swift-package`, and `k8s-debug`.
  A `lint.yml` workflow validates frontmatter — the registry's quality gate. In-cluster: a
  sync CronJob plus a ToolHive `MCPServer` so agents can discover skills by description.
- **Context graph** — Neo4j (single instance, `rook-ceph-block`) behind the Graphiti MCP
  server, with CronJob ingesters for GitHub repos/PRs, live k8s inventory, and the yakir
  role catalogue. Starts small and useful rather than attempting 150 node kinds.
- **Assistant** — Open WebUI pointed at LiteLLM, OIDC via Keycloak, tools via the MCP
  gateway. This is the human surface over everything above.

## Capacity

Default `terraform.tfvars.dist` gives 5 workers × 8 GB = 40 GB, and after kubelet, CRI,
Rook-Ceph OSDs, Prometheus, Grafana and Loki (all of which `deploy-to-libvirt` installs —
it pins `SIZING=large`) there is not enough left. Factory baseline is ~8–9 GiB, peaking
~16–20 GiB with runners and workspaces active.

Raising workers to **12288 MB** gives 3×6 + 5×12 = 78 GB of ricosrv's 123 GB usable,
leaving room for the host, Nexus's JVM and MinIO. 16384 would be more comfortable for the
cluster but squeezes those. CPU stays as-is: 3×2 + 5×4 = 26 of 28 threads, already at the
line — ARC runners and Coder builds will contend, and that is the expected trade on one box.

Disk is fine: 750 GB of Ceph across 5 workers on the 1 TB `/var/lib/libvirt` SSD.

## Operator prerequisites — things I cannot do

1. **Power ricosrv back on.** Everything blocks on this.
2. **ricostation ufw** — the cluster subnet must reach the model:
   `sudo ufw allow from 192.168.3.0/24 to any port 8080 proto tcp`.
   Arm the documented rollback first:
   `sudo systemd-run --on-active=300 --unit=ufw-rollback /usr/sbin/ufw --force disable`,
   and run it from a `192.168.2.0/24` host — from `192.168.3.x` you will lock yourself out.
3. **Give the model server a key** — add `--api-key <secret>` to `LLAMA_EXTRA` in
   `/etc/default/llama-server`. Once step 2 lands, two subnets can reach an open endpoint.
4. **GitHub**: a GitHub App on `ricofehr` for ARC, and a deploy key for `ai-factory`.
5. **DNS** for `*.{{ global_domain }}` (or pass `--kube-domain`).
6. **Run `./deploy-to-libvirt`** — `CLAUDE.md` forbids me provisioning real VMs.

## Verification

Everything below runs offline, with no cluster:

1. `cd ansible && ansible-galaxy collection install -r requirements.yml -p ./collections`
2. `cd ansible && ansible-lint` — must be clean at `profile: production`. From `ansible/`,
   not the repo root, per `CLAUDE.md`.
3. `shellcheck -e SC1091 up deploy-to-libvirt` — both stay clean.
4. `tflint --chdir=tf/libvirt` — 29 pre-existing warnings; assert no regression.
5. `helm template` every chart with the exact values the manifests pass, piped through
   `kubeconform` against the k8s 1.35 schema. This is the real gate for MR2–MR4 and catches
   the class of error that only shows up at apply time.
6. Render the Coder Terraform template with `terraform fmt -check`; `terraform` is not
   installed locally (it lives on ricosrv), so validation there is `tflint` only.
7. Validate every new `SKILL.md` frontmatter against the marketplace schema.
8. **No apply, no `terraform apply`, no playbook run against a live cluster.**

## Risks worth stating up front

- **The 2-slot model server is the factory's bottleneck.** One agent doing a long
  refactor saturates half the capacity. `max_parallel_requests: 2` keeps it honest rather
  than failing under load, but this stack will feel slow with more than a couple of
  concurrent agents. Claude Code on your subscription is the release valve.
- **Single-box blast radius.** Argo CD, the registry it pulls from (Nexus), and the cluster
  all sit on ricosrv, which was down when I probed. That is a lab, not a fault — but the
  factory inherits it.
- **Neo4j is the heaviest single addition** (~2 GiB) for the least immediately-proven value.
  If capacity bites, MR4's context graph is the first thing to cut.
