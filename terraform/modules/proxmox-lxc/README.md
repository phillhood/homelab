# proxmox-lxc

Creates an unprivileged Proxmox LXC. Used by CT 100 `pihole` and CT 101 `music`.

## The `ignore_changes` block is load-bearing — do not remove it

```hcl
lifecycle {
  ignore_changes = [
    features,
    mount_point,
    operating_system[0].template_file_id,
  ]
}
```

`features` and `mount_point` exist because **Ansible sets those two attributes and
Terraform must not fight it.** Proxmox reserves container feature flags and bind mounts for `root@pam`; the
scoped `terraform@pve` token gets a 403 on both, so the module deliberately does not
expose them and `music_storage/tasks/container_mount.yaml` sets them with `pct set`
instead.

The bpg provider reads both back on refresh. Seeing values present that the
configuration does not declare, it plans to remove them. Measured on CT 101 by removing
each entry and running `terraform plan`:

| Removed | Result |
|---|---|
| `mount_point` | `Plan: 1 to add, 0 to change, 1 to destroy` — **the container is destroyed and recreated**, because `volume = "/mnt/music" -> null` forces replacement |
| `features` | `Plan: 0 to add, 1 to change, 0 to destroy` — strips `nesting=1,keyctl=1` in place, which breaks Docker inside the container |
| both | replacement, as above |

Losing CT 101 would not destroy the music library — that lives on the host at
`/mnt/music` and is only bind-mounted in — but it would take the Samba passdb, Syncthing's
device identity, and slskd's state with it.

`network_interface` was in this list and has been removed: measured, it produced no diff,
and keeping it meant NIC or bridge changes edited into `pihole.tf` or `music.tf` would be
silently ignored on a shared module.

## `template_file_id` is ignored for a different reason

Not because Ansible sets it — because it is a **create-time-only** attribute that forces
replacement when changed, and keeping the environment files pinned to whatever template
each container was originally built from would mean new containers are created from an
ever-staler template.

Measured 2026-07-26 on CT 100, by bumping only `pihole.tf` from `13.1-2` to `13.6-1`:

```
# module.pihole.proxmox_virtual_environment_container.this must be replaced
~ template_file_id = "...13.1-2..." -> "...13.6-1..."  # forces replacement
Plan: 1 to add, 0 to change, 1 to destroy.
```

With the entry in place, all five environment files were bumped to `13.6-1` and
`terraform plan` reported **No changes**.

**Read the field as forward-looking, not historical:** it is the template to use *if this
container is ever created*, not a record of what it was built from. Terraform state still
holds `13.1-2` for the five existing containers and cannot refresh it, because
`pct config` carries no reference to the source template — the `template:` key it does
show is the *is-this-container-a-template* flag, unrelated. That state/config divergence
is deliberate and inert.

Two consequences worth knowing:

- **The old template file can be deleted from the node.** Nothing at runtime reads it; the
  rootfs is an independent LV populated once at creation. `pve_templates` only downloads
  and never prunes, so old templates accumulate until removed by hand.
- **A deliberate replacement uses the config value, not the state value.** `ignore_changes`
  suppresses diffs; it does not affect what is sent on create. So
  `terraform apply -replace=module.registry...` rebuilds from `13.6-1`.

Recreating a container is *not* a substitute for upgrading one. A Debian point release is
a label for a set of package versions, not a distinct OS — `base-files` is what writes
`/etc/debian_version` — so `apt dist-upgrade` reaches the same versions a fresh template
would. See `ansible/roles/debian_lxc_base/README.md` for the upgrade path.

**If you believe an entry here is unnecessary, measure before deleting.** Remove it, run
`terraform plan`, read the output, and restore the file. A plan is read-only and never
touches infrastructure.

## What the module deliberately does not expose

`features` and `mount_point` are absent from `variables.tf` on purpose — adding them
would be code for an API call that always returns 403. See
`ansible/roles/music_storage/README.md`, "Why the bind mount is here and not in
Terraform".
