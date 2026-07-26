# proxmox-lxc

Creates an unprivileged Proxmox LXC. Used by CT 100 `pihole` and CT 101 `music`.

## The `ignore_changes` block is load-bearing — do not remove it

```hcl
lifecycle {
  ignore_changes = [
    features,
    mount_point,
  ]
}
```

Both entries exist because **Ansible sets those two attributes and Terraform must not
fight it.** Proxmox reserves container feature flags and bind mounts for `root@pam`; the
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

**If you believe an entry here is unnecessary, measure before deleting.** Remove it, run
`terraform plan`, read the output, and restore the file. A plan is read-only and never
touches infrastructure.

## What the module deliberately does not expose

`features` and `mount_point` are absent from `variables.tf` on purpose — adding them
would be code for an API call that always returns 403. See
`ansible/roles/music_storage/README.md`, "Why the bind mount is here and not in
Terraform".
