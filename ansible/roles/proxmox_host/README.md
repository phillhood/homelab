# proxmox_host

Brings a bare Proxmox VE node to Terraform-ready state, and carries the one maintenance task
that has to run against the hypervisor itself rather than a guest. Everything here is scoped
to `hosts: proxmox`; this role never touches anything inside an LXC or VM.

## Usage

| Tag | Does |
|---|---|
| `repos` | swaps the enterprise APT repos for no-subscription via `deb822_repository` |
| `dns` | points the host resolver at Pi-hole |
| `ssh-keys` | operator public keys into root's `authorized_keys` (`exclusive: false`) |
| `terraform-user` | the `pveum` account, role and ACL, plus its API token |
| `fstrim` | thin-pool reclaim. Tagged `never` — only runs when named |
| `proxmox_host` | everything except `fstrim` |

```bash
ansible-playbook playbooks/site.yaml --limit kvatch --tags fstrim   # maintenance, on demand
ansible-playbook playbooks/site.yaml --limit kvatch \
  -e rotate_terraform_token=true                                    # rotate the API token
```

## Variables

| Variable | Default | Notes |
|---|---|---|
| `terraform_user` | `terraform@pve` | |
| `terraform_role` | `Terraform` | |
| `terraform_role_privs` | see `group_vars/proxmox.yaml` | the exact priv-list, enforced |
| `rotate_terraform_token` | `false` | `true` removes and reissues |
| `pve_repositories`, `pve_suite`, `pve_signing_key` | `group_vars/proxmox.yaml` | |
| `root_authorized_keys` | `group_vars/proxmox.yaml` | |
| `resolv_fallback_nameservers` | `[1.1.1.1]` | |

The Terraform token secret is written straight into `proxmox.sops.yaml` with `sops set`, and
the tasks that touch it are `no_log`. The role bootstraps an encrypted secrets file if none
exists.

## Invariants

- **`fstrim` must keep `[fstrim, never]` and nothing else.** Naming *any* tag on a
  `never`-tagged task activates it, so adding a role tag here would make
  `--tags proxmox_host` run thin-pool reclaim across every container.
- **Reclaim only works by entering the container's mount namespace.** `nsenter -t <pid> -m --
  fstrim /`, with the pid from `lxc-info -n <vmid> -p -H`. Three plausible alternatives all
  fail: `fstrim` inside an unprivileged LXC gets `FITRIM ioctl failed: Operation not
  permitted`; `fstrim` against the container's rootfs path on the host trims the *host's*
  filesystem; and the host's `fstrim.timer` only walks mounts visible in the host namespace,
  so it never reclaims a running container's blocks no matter how long it has been enabled.
- **`fstrim.yaml` filters `pct list` to `running` first.** A stopped container has no init
  pid to enter, and `nsenter` fails closed on a malformed value rather than falling through
  to host pid 1.
- **`ssh_keys.yaml` uses `exclusive: false`** — it only adds, never prunes keys it does not
  know about.
- The Proxmox API token cannot set container feature flags or bind mounts; `terraform@pve`
  gets a 403 on both. That is why those go through `pct set` in `music_storage` rather than
  Terraform.

Rationale and the measured reclaim result are in the local notes for this role.
