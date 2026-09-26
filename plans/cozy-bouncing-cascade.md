# Fix the reboot-fragile control-plane endpoint

## Context

The `large` libvirt cluster went down ~26h after a clean deploy. Diagnosis on
`k8s-manager1` (192.168.3.210) showed the control plane itself was **healthy**
(`/healthz` → 200, etcd/scheduler/controller-manager all up) — but the name
every component uses to reach it, `control-plane:6443`, resolved nowhere.

Two independent latent defects in this repo, both detonated by the reboot at
2026-09-26 11:25 CEST:

**1. The `linux_hardening` role plants a NIC-rename time bomb.**
`roles/linux_hardening/templates/grub_default:5` overwrites `/etc/default/grub`
wholesale with `GRUB_CMDLINE_LINUX="… net.ifnames=0 biosdevname=0 security=yama"`,
under a task named only "Enable yama module at boot". Its `Update grub` handler
runs `update-grub2` but **never reboots** — and the `Reboot vm` handler in
`roles/linux_hardening/handlers/main.yml:9` is dead code that nothing notifies.
So the rename sat dormant. Evidence:

```
/etc/default/grub  mtime 2026-09-25 09:34  ← the deploy wrote it
/boot/grub/grub.cfg mtime 2026-09-26 06:25  ← unattended linux-image-6.8.0-142 ran update-grub
boot -2 (Sep 25 09:28) cmdline: … ro console=tty1            ← no net.ifnames, NIC = ens3
boot  0 (Sep 26 14:17) cmdline: … net.ifnames=0 biosdevname=0 … ← NIC renamed to eth0
keepalived: Sep 25 09:37 "(VI_1) Entering MASTER STATE"       ← worked on ens3
keepalived: Sep 26 11:25 "Non-existent interface specified"   ← ens3 gone, exit 2
```

`deploy-to-libvirt:8` hardcodes `VM_ETH="ens3"` and passes it as
`-e keepalived_eth` (line 278), so keepalived was configured for an interface
that the repo's own hardening role guarantees will disappear. VIP
`192.168.3.250` never came back.

**2. cloud-init wipes `/etc/hosts` on every boot.**
`tf/libvirt/cloud_init.cfg:3` sets `manage_etc_hosts: true`, which makes
cloud-init re-render `/etc/hosts` from the distro template with
`frequency: always`. That deletes the `192.168.3.250 control-plane` line (and
all manager/node entries) written by
`roles/k8s/tasks/local_hosts_file.yml`. Confirmed: `/etc/hosts` mtime
`14:17:17`, exactly the boot, and `cloud-init.log` logs
`Running module update_etc_hosts … with frequency always`.

**Resulting cascade** — one unresolvable name took out the whole data plane:

| Component | Points at | Result |
|---|---|---|
| kube-proxy (all 8) | `control-plane:6443` | `no such host` → never syncs → **zero service rules** (empty IPVS table) |
| `kubernetes` ClusterIP 10.96.0.1 | — | dead, despite correct endpoints |
| Cilium init `config` | `10.96.0.1:443` | `i/o timeout` → `Init:CrashLoopBackOff` ×33 on all managers |
| Worker kubelets | `control-plane:6443` | stopped posting → all 5 **NotReady** |

Managers stayed `Ready` only because kubeadm wrote their `kubelet.conf` /
`controller-manager.conf` / `scheduler.conf` with the literal IP.

**Outcome wanted:** a deploy that survives reboots — the NIC name is settled
during the deploy instead of hours later, `/etc/hosts` keeps the endpoint
entry, and a mismatch fails loudly at deploy time instead of silently hours on.

**Scope:** repository only. The live cluster stays broken; remediating it is a
separate step (see *Not in scope*).

## Approach

### 1. Settle the NIC rename during the deploy — `eth0` everywhere

Keep `net.ifnames=0` (it makes libvirt naming `eth0`/`eth1`, consistent with the
Vagrant path's existing `keepalived_eth: "eth1"` in
`ansible/group_vars/managers/keepalived:7`), but apply it *inside* the deploy.

- **`ansible/roles/linux_hardening/tasks/grub2.yml`** — add `Reboot vm` to the
  `notify:` list, after `Update grub`. Handlers fire in definition order, and
  `handlers/main.yml` already defines `Update grub` (line 3) before
  `Reboot vm` (line 9), so the order is correct with no handler-file change.
  This activates existing dead code rather than adding anything new.
  Retitle the task from "Enable yama module at boot" — it writes the whole grub
  default file, including the network-naming policy, and the current name hides
  that.
- **`ansible/roles/linux_hardening/templates/grub_default`** — no content
  change; add a short comment on the `GRUB_CMDLINE_LINUX` line recording that
  `net.ifnames=0` is what pins interfaces to `eth*`, so the next reader does not
  "clean it up" and reintroduce the outage.
- **`deploy-to-libvirt:8`** — `VM_ETH="ens3"` → `VM_ETH="eth0"`.

Play order makes this safe: `linux_hardening` is in play 1
(`managers` + `nodes`), `keepalived` in play 2 (`managers`), per
`ansible/playbook.yml:12,27`. The reboot lands at the end of play 1, before
anything is configured against an interface name, and before k8s exists.

### 2. Make the netplan stanza survive the rename

**`tf/libvirt/network_config_dhcp.cfg`** currently keys on the literal `ens3`,
which stops matching after the rename — DHCP presently only still works by
cloud-init fallback, and the `mtu: 1500` is silently lost. Replace the literal
key with a glob match so it is correct both before and after:

```yaml
version: 2
ethernets:
  primary:
    match:
      name: "e*"
    dhcp4: true
    mtu: 1500
```

Consumed by `tf/libvirt/main.tf:50` (managers) and `:175` (workers).

### 3. Stop cloud-init from wiping `/etc/hosts`

Two layers, because fixing only the Terraform side leaves every already-deployed
VM broken (their user-data is already baked).

- **`tf/libvirt/cloud_init.cfg:3`** — `manage_etc_hosts: true` →
  `manage_etc_hosts: localhost`. `localhost` keeps cloud-init maintaining the
  `127.0.1.1 <fqdn>` self-resolution entry (which `sudo` and kubelet want) while
  no longer re-rendering the whole file from the template, so Ansible's entries
  survive. Plain `false` would also stop the wipe but drops the FQDN entry.
- **`ansible/roles/k8s/tasks/local_hosts_file.yml`** — prepend a task writing
  `/etc/cloud/cloud.cfg.d/99-k8s-etc-hosts.cfg` containing
  `manage_etc_hosts: localhost`, guarded on `/etc/cloud` existing so the Vagrant
  path is unaffected. This belongs here: the file's stated job is managing
  `/etc/hosts`, and it is pointless to write entries that another service
  deletes at next boot. Must come **before** the existing `lineinfile` tasks.
  Use `ansible.builtin.copy` with `content:` — idempotent, no handler needed
  (cloud-init reads it at next boot).

### 4. Add the `control-plane` name to the apiserver certSANs

**`ansible/roles/k8s/templates/kubeadm.conf.j2`** — the `apiServer.certSANs`
block (lines 17–22) lists only per-manager IPs and hostnames, so the VIP and the
endpoint name the cluster is actually addressed by are absent. Add
`k8s_controlplane_endpoint` and `k8s_controlplane_endpoint_ip` (both defined in
`ansible/group_vars/all/k8s:6-7`) to `apiServer.certSANs` only.

Leave `etcd.serverCertSANs` / `peerCertSANs` alone — etcd peers address each
other by real node IP; the VIP has no business there.

### 5. Fail loudly on an interface mismatch

**`ansible/roles/keepalived/tasks/main.yml`** — add an `assert` before the
template task that `keepalived_eth` is in `ansible_facts.interfaces`, with a
message naming the configured value and the interfaces actually present. This is
the guard that would have turned this silent multi-hour outage into an immediate,
readable deploy failure. Keep it to one assertion — the template task at line 9
otherwise happily writes a config keepalived rejects with exit 2.

### 6. Drive-by in a file already being edited

**`tf/libvirt/cloud_init.cfg`** declares `runcmd:` **twice** (once around line 35
with the `runcmd.log` line, then again immediately after). YAML keeps only the
last, so the first is silently discarded — dead config. Merge into a single
`runcmd:` block preserving both. Flagged separately in the commit body; say so
if you would rather I leave it.

## Files

| File | Change |
|---|---|
| `deploy-to-libvirt` | `VM_ETH="ens3"` → `"eth0"` |
| `ansible/roles/linux_hardening/tasks/grub2.yml` | notify `Reboot vm`; honest task name |
| `ansible/roles/linux_hardening/templates/grub_default` | comment pinning rationale |
| `tf/libvirt/network_config_dhcp.cfg` | literal `ens3` → `match: name: "e*"` |
| `tf/libvirt/cloud_init.cfg` | `manage_etc_hosts: localhost`; merge duplicate `runcmd` |
| `ansible/roles/k8s/tasks/local_hosts_file.yml` | new first task: cloud-init drop-in |
| `ansible/roles/k8s/templates/kubeadm.conf.j2` | endpoint name + VIP in `apiServer.certSANs` |
| `ansible/roles/keepalived/tasks/main.yml` | `assert` interface exists |

## Verification

Static gates (all must be clean — these are the repo's stated gates in
`CLAUDE.md`):

```sh
shellcheck up deploy-to-libvirt
cd ansible && ansible-galaxy collection install -r requirements.yml -p ./collections
cd ansible && ansible-lint            # from ansible/, profile production
tflint --chdir=tf/libvirt
```

Plus, since two edited files are parsed as YAML by other tooling:

```sh
python3 -c "import yaml,sys; yaml.safe_load(open('tf/libvirt/network_config_dhcp.cfg'))"
# cloud_init.cfg carries ${…} terraform placeholders but is still valid YAML —
# parse it to prove the duplicate-runcmd merge did not break it, and assert the
# key appears exactly once.
```

Render check for the Jinja change without provisioning anything:

```sh
cd ansible && ansible-lint roles/k8s   # catches template syntax
```

End-to-end confirmation is **not** run here: `./deploy-to-libvirt`, `./up`,
`terraform apply` and `terraform destroy` all provision real VMs and
`CLAUDE.md` forbids them. The real proof is a fresh `./deploy-to-libvirt large`
followed by a deliberate `reboot` of all six VMs, then checking
`getent hosts control-plane`, `systemctl is-active keepalived`, and
`kubectl get nodes` — that is a human's call to make.

## Not in scope

- **The live cluster stays down.** Repo changes do not touch it. Remediation is
  a separate ask: on each manager `sed -i 's/ens3/eth0/g'
  /etc/keepalived/keepalived.conf`, re-add `192.168.3.250 control-plane` to
  `/etc/hosts`, `systemctl start keepalived`; then the same hosts line on the 5
  workers + `systemctl restart kubelet`. Note I only have an SSH key for
  `.210` — `.211`, `.212` and all workers refused `~/.ssh/id_ed25519`.
- **certSANs only affect new clusters.** Certificates are generated at
  `kubeadm init`; the existing cluster would need `kubeadm certs renew` plus a
  regenerated apiserver cert to pick the new SAN up.
- `kubeadm.conf.j2` still uses `apiVersion: kubeadm.k8s.io/v1beta3` on a v1.35.2
  cluster. It parses today, but v1beta4 is the current schema. Noted, not
  touched.
