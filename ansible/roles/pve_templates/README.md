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

### The LXC pin was coupled to Terraform — that coupling is now broken

`pveam` only ever serves the current point release. On 2026-07-25 the pin moved
`13.1-2` → `13.6-1` because `13.1-2` had aged out of the catalog and a fresh node could no
longer download it.

That used to be a live problem. Changing `template_file_id` on an existing container
**forces replacement** — measured as `1 to add, 1 to destroy` against the running Pi-hole —
so the environment files were left pinned to `13.1-2` while this role installed `13.6-1`.
That divergence meant a **fresh node rebuild would fail**: the role would install `13.6-1`
while `pihole.tf` asked for a tarball that no longer exists upstream.

**Resolved 2026-07-26** by adding `operating_system[0].template_file_id` to the module's
`ignore_changes` — see `terraform/modules/proxmox-lxc/README.md` for the measurements. All
five environment files now reference `13.6-1` and `terraform plan` reports **No changes**.

The earlier plan recorded here — rebuild Pi-hole onto the newer template, restoring gravity
from a Teleporter export — is **no longer necessary** and should not be attempted for this
reason. Read `template_file_id` as *the template to use if this container is ever created*,
not a record of what it was built from.

### This role never prunes, so old templates accumulate

`lxc_template.yaml` downloads `lxc_template_name` when absent and does nothing else. It has
no `state: absent` path, so every point-release bump leaves the previous tarball on disk
(~124 MB each) until removed by hand.

Removing an old one is safe once nothing references it, and this is worth checking rather
than assuming:

```bash
rg 'debian-13-standard' terraform/environments/*/*.tf   # nothing should name the old one
ssh root@192.168.1.101 'pveam list local'
ssh root@192.168.1.101 'pveam remove local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst'
```

Nothing at runtime needs it — `pct config` holds no reference to the source template, and a
container's rootfs is an independent LV populated once at creation. Terraform state still
carries the old value for pre-existing containers and cannot refresh it, which is inert.

**Removal is one-way.** `pveam available` no longer lists superseded point releases, so a
deleted old template cannot be re-downloaded.
