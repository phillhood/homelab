# Homelab

***v2!***

Proxmox VE on one node, with a cluster planned. Terraform provisions the guests, Ansible
configures them.

## Layout

| | |
|---|---|
| `ansible/` | configures what Terraform created |
| `kubernetes/` | cluster manifests — Phase 5, not live yet |
| `terraform/` | provisions guests — containers and VMs |

The layers do not cross: nothing in `ansible/` creates or destroys a guest, and Terraform
never configures anything inside one. Where a setting can only come from the hypervisor —
bind mounts, container feature flags — Ansible applies it over SSH and the Terraform module
carries a matching `ignore_changes`, so the two do not fight.

## Usage

Everything goes through the Makefile.

```bash
make help        # every target, grouped by how dangerous it is
make lint        # syntax + ansible-lint, contacts nothing
make check       # dry run with diffs — what WOULD change
make apply       # converge
make verify      # read-only health probes against every system
make idempotent  # converge twice, fail unless the second run changes nothing
```

The safe path is `make preflight` — lint, take a backup, show the diff — then `make apply`.

Narrow any target with `LIMIT=` and `TAGS=`, e.g. `make check LIMIT=pihole TAGS=config`.

**A second `apply` changes nothing.** That is the property everything else is checked
against. The one deliberate exception is `make backup`, which is `changed` every run — a
backup that never changes is broken.

## Reverting

Two paths, covering different things.

```bash
make backup           # config and state into the local backup tree
make backups-list     # what has been captured

make snapshots        # containers, their snapshots, thin-pool headroom
make snapshot CT=104  # before an OS upgrade
make rollback CT=104  # DESTRUCTIVE: stop, roll back, restart
```

`apt dist-upgrade` has no undo, so an LVM snapshot is the only real way back from one. The
music container cannot be snapshotted at all — it holds a host-path bind mount — so its
contents are protected by a restic repository instead. The procedure is in
`ansible/roles/debian_lxc_base/README.md`.

## Conventions

- **Secrets live in `*.sops.yaml`**, decrypted at run time. The rule is *would leaking this
  let someone in?* — public keys and device IDs are not secrets. `make secrets` confirms
  every file is encrypted at rest.
- **One definition per value.** Role `defaults/` owns the role's own values; `group_vars/`
  carries only what is environment-specific. A value in both means editing the default
  silently does nothing.
- **No explanatory comments in config.** Task names say what a task does; reasoning lives in
  documentation. That includes play names and assert messages.
- **Every role README has an `## Invariants` list.** Read it before changing that role — each
  entry is a trap that cost real time to find, and several describe a change that looks like
  a simplification and is not.
- The toolchain is pinned in `pyproject.toml` and `uv.lock`, the collections in
  `ansible/requirements.yaml`, so a fresh clone gets the same versions.

`ansible/README.md` covers the playbook and role layout in full.

## Documentation

Usage documentation lives with the code it describes and is committed.

Everything specific to this particular lab — hardware, network topology, the service
inventory, the roadmap, and the decision notes behind each role — is kept locally and backed
up rather than committed.
