# pve_templates

Builds the guest templates Terraform clones.

## What it produces

- **LXC template** `debian-13-standard_*` in `local` (via `pveam`).
- **VM template** VMID 9000 `debian-13-cloudinit`: Debian genericcloud qcow2 with
  `qemu-guest-agent` baked in, serial console, `--cpu host`, converted to a template.

## Idempotency

- LXC: skipped if `pveam list local` already contains the pinned tarball.
- VM: the whole build block is skipped if `qm status 9000` succeeds.

Both guards are `command` tasks whose registered output a later `when:` depends on, so
both carry `check_mode: false`. Without it, `--check` skips them and the VM guard fails
on an undefined `rc` rather than reporting the block as skipped.

## Bumping versions

- Update `lxc_template_name` and/or `vm_template_image_url` in `defaults/main.yaml`.
- To rebuild the VM template, destroy the old one first: `qm destroy 9000` (Terraform
  clones are full copies, so existing guests are unaffected), then re-run the role.

### The LXC pin is coupled to Terraform — read before bumping

`pveam` only serves the current point release. On 2026-07-25 the pin moved
`13.1-2` → `13.6-1` because `13.1-2` had aged out of the catalog and a fresh node
could no longer download it.

`terraform/environments/kvatch/pihole.tf` still references `13.1-2`, deliberately.
Changing `template_file_id` on an existing container **forces replacement** — verified
with `terraform plan`, which reported `1 to add, 1 to destroy` against the running
Pi-hole. Since CT 100 serves DNS for the whole network, that is not a passive edit.

Consequences to keep in mind:

- **Existing node:** safe. `13.1-2` is still on disk, so Terraform stays satisfied even
  though the tarball is no longer downloadable.
- **Fresh node rebuild:** this role installs `13.6-1`, but `pihole.tf` asks for `13.1-2`,
  which cannot be fetched — the Pi-hole deploy would fail at the Terraform layer.

Resolving that means deliberately rebuilding Pi-hole onto the newer template: take a
Teleporter export first (`homelab_backups`), update `pihole.tf`, apply, then restore
gravity and settings from the archive.
