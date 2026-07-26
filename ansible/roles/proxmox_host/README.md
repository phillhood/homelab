# proxmox_host

Brings a bare Proxmox VE node to Terraform-ready state, and carries the one
maintenance task that has to run against the hypervisor itself rather than any
guest: thin-pool reclaim.

## What it does

- **`repos.yaml`** — replaces the enterprise APT repositories with the no-subscription
  ones via `deb822_repository`, and removes the renamed-but-still-present
  `pve-enterprise.sources.disabled` file so it can't confuse a future `apt` run.
- **`dns.yaml`** — points the host's own resolver at Pi-hole.
- **`ssh_keys.yaml`** — ensures the operator's public keys are present in
  `root`'s `authorized_keys` (`exclusive: false`, so it only adds, never prunes
  keys it doesn't know about).
- **`terraform_user.yaml`** — idempotently creates the `pveum` service account,
  role and ACL grant Terraform authenticates as, bootstraps an encrypted
  `proxmox.sops.yaml` if one doesn't exist yet, and issues (or rotates, via
  `rotate_terraform_token: true`) its API token. The token secret is written
  straight into SOPS with `sops set` and the tasks that touch it are `no_log: true`
  — it is never visible in playbook output.
- **`fstrim.yaml`** — reclaims thin-pool blocks from every *running* container's
  LV. Tagged `[fstrim, never]`; see below for why it needs its own task at all.

Every task here is scoped to the Proxmox host (`hosts: proxmox`), not the guests —
this role never touches anything inside an LXC or VM.

## Thin-pool reclaim needs its own task because nothing else does this job

The pool's discard mode is already `passdown` — this was never an LVM
configuration problem. The gap is that **nothing in the normal stack ever tells
the thin pool that a running container's deleted blocks are free**, and three
plausible-looking fixes all fail for different reasons:

1. **`fstrim` run *inside* an unprivileged LXC** fails outright:
   `fstrim: /: FITRIM ioctl failed: Operation not permitted`. An unprivileged
   container cannot issue the ioctl against its own root filesystem, discard
   mode or not.

2. **`fstrim` run against the container's rootfs path *on the host***
   (e.g. `fstrim /var/lib/vz/...` or wherever `pct`'s mount point resolves to)
   trims the **host's** own filesystem, not the container's. The container's LV
   is mounted inside the container's own mount namespace; from the host's
   mount namespace, the path the container sees as `/` is a different,
   unrelated mount (or nothing at all, for a running container) — the ioctl
   succeeds but reclaims the wrong filesystem's free space.

3. **The host's `fstrim.timer`** (systemd's stock periodic trim) only walks
   mount points visible in the *host's* namespace. A running container's
   rootfs is never one of them, so the timer silently never reclaims any
   container's thin-pool blocks, ever, no matter how long it's been enabled.

The only thing that actually works is **entering the container's own mount
namespace before trimming**: resolve the container's init PID
(`lxc-info -n <vmid> -p -H`) and run `nsenter -t <pid> -m -- fstrim /` from the
host. That's exactly what `fstrim.yaml` does, filtering `pct list` to rows with
status `running` first (a stopped container has no init PID to enter, and
`nsenter` fails closed with `invalid PID argument` on any malformed value rather
than falling through to host PID 1).

### Why it's tagged `never` and doesn't run by default

`fstrim` is a maintenance action, not part of the steady-state config this
role otherwise brings a host to — it has no idempotent "already trimmed"
state to converge toward the way the other tasks do, and running it
unconditionally on every `site.yaml` converge would add meaningful I/O load
for no benefit on hosts that don't need it yet. Ansible's built-in `never`
tag keeps it out of every ordinary run; it only executes when named
explicitly:

```bash
ansible-playbook playbooks/site.yaml --limit kvatch --tags fstrim
```

`make check LIMIT=kvatch` (no `--tags fstrim`) shows zero fstrim-related tasks
in its output — confirmed empirically, not just asserted from the tag
semantics.

### Measured result the first time this ran

Every running container reclaimed real space; CT 100 (the pihole container,
which had accumulated the most cruft) dropped from **59.17% to 40.17%**
thin-pool `data_percent`. Every other running container also dropped by a
smaller amount, confirming the mechanism works fleet-wide and isn't specific
to whichever container happened to be tested. Reproduce the measurement with:

```bash
ssh root@192.168.1.101 'lvs --noheadings -o lv_name,data_percent pve | grep vm-'
```
