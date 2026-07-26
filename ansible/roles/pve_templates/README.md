# pve_templates

Builds the guest templates Terraform clones.

## Usage

| Tag | Does |
|---|---|
| `lxc-template` | downloads `lxc_template_name` into `local` via `pveam`, if absent |
| `vm-template` | builds VMID 9000 `debian-13-cloudinit`, if `qm status` fails |
| `pve_templates` | both |

The VM template is a Debian genericcloud qcow2 with `qemu-guest-agent` baked in, serial
console, `--cpu host`, converted to a template.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `lxc_template_name` | `debian-13-standard_13.6-1_amd64.tar.zst` | |
| `vm_template_id` | `9000` | |
| `vm_template_image_url` | Debian trixie genericcloud | |
| `vm_template_memory`, `vm_template_cores` | `2048`, `2` | |
| `pve_iso_storage`, `pve_disk_storage` | `local`, `local-lvm` | |

To bump either, change the variable. To rebuild the VM template, `qm destroy 9000` first —
Terraform clones are full copies, so existing guests are unaffected — then re-run.

## Invariants

- **Both idempotency guards need `check_mode: false`.** They are `command` tasks whose
  registered output a later `when:` depends on; without it `--check` skips them and the VM
  guard fails on an undefined `rc` rather than reporting the block as skipped.
- **This role never prunes, so old templates accumulate** at ~124 MB each. Removing one is
  safe once nothing references it, and that is worth checking rather than assuming:

  ```bash
  rg 'debian-13-standard' terraform/environments/*/*.tf   # nothing should name the old one
  ssh root@192.168.1.101 'pveam list local'
  ssh root@192.168.1.101 'pveam remove local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst'
  ```

- **Removal is one-way.** `pveam available` no longer lists superseded point releases, so a
  deleted old template cannot be re-downloaded.
- **Read `template_file_id` in Terraform as "the template to use if this container is ever
  created", not a record of what it was built from.** Changing it used to force replacement;
  the module now carries `ignore_changes` for it. Nothing at runtime needs the source
  template — `pct config` holds no reference and a container's rootfs is an independent LV
  populated once at creation.

Rationale and the template-pin history are in the local notes for this role.
