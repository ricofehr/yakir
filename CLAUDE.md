# CLAUDE.md

Guidance for working in this repository. [README.md](README.md) covers what it
does and how to deploy it; this file is about not breaking it.

## What this is

Yakir installs a base Kubernetes cluster on Ubuntu (tested on Noble) with
kubeadm. Three deployment paths, one Ansible stack behind all of them:

- **Vagrant** (`./up`) — local VMs, sizings `small` / `medium` / `large`.
- **Terraform + libvirt** (`./deploy-to-libvirt`) — VMs on a KVM hypervisor.
- The deploy scripts create three symlinks that everything else depends on:
  `Vagrantfile`, `ansible/inventory`, and `ansible/sizing_vars.yml`. They are
  gitignored and generated — never commit them, never hand-edit them.

## Commands

```sh
cd ansible && ansible-lint          # the gate; must be clean at profile "production"
cd ansible && ansible-galaxy collection install -r requirements.yml -p ./collections
tflint --chdir=tf/libvirt           # terraform is not installed locally; tflint only
shellcheck up deploy-to-libvirt     # both must stay clean
```

**Run `ansible-lint` from `ansible/`, not from the repo root.** `ansible.cfg`
lives there and sets `collections_path`; from anywhere else every module
resolves as unknown and you get ~30 phantom `syntax-check[unknown-module]`
errors that are really one missing install.

CI (`.github/workflows/ansible-lint.yml`) copies `ansible/.ansible-lint` and
`ansible/requirements.yml` to the root and runs the ansible-lint action there.
Local and CI invocations differ; local is the one you can actually run.

## Layout that matters

```
ansible/
  group_vars/all/global    global + transversal variables — the widest scope
  group_vars/{leader,managers,nodes}/
  sizing_vars/             per-sizing VM topology (small/medium/large)
  inventories/             inventory_small | inventory_medium | inventory_large
  roles/                   20 roles, see README for the one-line description of each
tf/libvirt/                KVM provisioning
vagrantfiles/              one Vagrantfile flavour per sizing
```

Variable precedence is load-bearing: `group_vars/` overrides a role's
`defaults/main.yml`. Put environment-shaped values in `group_vars`, overridable
defaults in `defaults/`, and genuine constants in role `vars/`. Reaching for a
higher scope to fix a value that belongs in a role default is how this stack
gets hard to reason about.

## Playbook order

`ansible/playbook.yml` runs four plays, and the order is a dependency chain,
not a preference:

1. **managers + nodes** — `internal_repos`, `base`, `linux_hardening`, `crio`
2. **managers**, `serial: 1` — `helm`, `keepalived`, `k8s`, `haproxy`
3. **nodes** — `k8s` (worker tag)
4. **leader** — `cni`, `csi`, `postinstall`, `ingress`, `cert_manager`,
   `reloader`, `reflector`, `monitoring`, `logcollect`, `backup`, `bench`,
   `gitops`

`serial: 1` on the manager play is deliberate — control-plane init is not
parallelisable. Some cluster roles are conditional on `global_cluster_sizing`
(`monitoring` skips `small`, `logcollect` runs only on `large`) or on a secret
being set (`backup`, `gitops`). Preserve those guards when editing.

## Rules

- **Idempotence is the contract.** Every task must be safe to run twice. Prefer
  modules over `command`/`shell`; when you must shell out, set `changed_when`
  and `creates`/`removes` deliberately.
- **Readiness gates exclude terminal pods.** Every `kubectl wait
  --for=condition=Ready` carries
  `--field-selector=status.phase!=Failed,status.phase!=Succeeded`, alongside any
  `--selector`. An Evicted pod never goes Ready and would hold the wait for its
  full timeout. Never narrow it to `status.phase=Running`: `kubectl wait`
  resolves its selection once and then watches those pods by name, so that form
  passes as soon as the fastest pod is ready.
- **Don't relax the linter.** `.ansible-lint` pins `profile: production`. A
  targeted `# noqa` with a comment explaining why beats widening
  `exclude_paths`.
- **Collections are pinned** in `requirements.yml`. Don't float a version to
  make something work; the pin is the reproducibility guarantee.
- **Never commit** `ansible/inventory`, `ansible/sizing_vars.yml`,
  `Vagrantfile`, `ansible/group_vars/master/passwords`, `*.tfvars`, or
  `*.tfstate`. All are gitignored for a reason.
- **Never run `terraform apply` or `destroy`.** Produce a plan and hand it to a
  human. Same for `./up` and `./deploy-to-libvirt` — these provision real VMs.
- Task names are read by an operator watching a run at 3am. Write them for that
  reader.
