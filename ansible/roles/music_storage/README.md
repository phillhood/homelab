# music_storage

Everything about the music disk on the host: the SSD itself, its layout, the bind mount
into CT 101, and the content backup that protects it. Runs on `kvatch`, not in the
container.

## Usage

| Tag | Does |
|---|---|
| `thunderbolt` | install `bolt` + `polkitd`, enroll the enclosure |
| `disk` | partition + `mkfs.ext4`, behind four guards |
| `host-mount` | fstab entry by UUID, then mount |
| `layout` | `library/`, `downloads/{incomplete,complete}/`, `.state/museek/`, `.meta/` |
| `storage` | all four of the above |
| `bind-mount` | `pct set` for `features` and `mp0` — deliberately outside `storage` |
| `music-backup` | restic repository, `/usr/local/sbin/music-backup`, and its timer |

First build needs Terraform in the middle, because the bind mount needs both the host
directory and the container to exist:

```bash
ansible-playbook playbooks/music.yaml --tags storage      # enroll, format, mount, layout
terraform -chdir=terraform/environments/kvatch apply      # create CT 101
ansible-playbook playbooks/music.yaml --tags bind-mount   # attach, reboot CT
ansible-playbook playbooks/music.yaml                     # everything
```

Afterwards it runs in one pass — `container_mount.yaml` no-ops with a message when CT 101
does not exist yet.

## Content backup

restic repository at `/var/backups/restic/music` on `kvatch`, plus a daily timer. Built by
`backup.yaml`; the script it installs is the single implementation, and `homelab_backups`
runs that same script rather than reimplementing it.

```bash
make backup-music-content                      # run now
make music-snapshots                           # what is held
make music-restore DEST=/var/tmp/restore-test  # add SNAPSHOT=<id> for an older one
```

`make backup-music` is a different thing — a manifest of path, size and mtime, not the
files.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `music_format_disk` | `false` | the format gate; `true` only to format |
| `music_disk_uuid` | `host_vars` | pinned to the real library disk |
| `music_host_mount` | `/mnt/music` | |
| `music_device_timeout` | `60` | fstab `x-systemd.device-timeout` |
| `music_backup_repo` | `/var/backups/restic/music` | |
| `music_backup_excludes`, `music_backup_stack_excludes` | | paths kept out of the snapshot |
| `music_backup_keep_daily` / `_weekly` / `_monthly` | `7` / `4` / `6` | restic retention |
| `music_backup_on_calendar` | `*-*-* 03:30:00` | timer schedule |

`music_gid`, `music_container_mount` and `music_stack_dir` come from
`group_vars/music_common.yaml`, a group holding both `kvatch` and `music1` so that both
sides of the bind mount move together. `music_host_gid` derives as `100000 + music_gid`.

**Requires** `restic_repo_password`, from `group_vars/proxmox.sops.yaml`.

## Invariants

**Disk**

- `mkfs -i 1048576` is fixed at format time. Losing it costs ~29 GiB of inode tables on an
  empty filesystem, and only another reformat gets it back.
- Guard 2 — an existing ext4 labelled `music` refuses the format — is what makes re-runs
  safe. Prove it still bites: `--tags disk -e music_format_disk=true` must **fail**.
- Never test the guards against the real disk. Use a loopback, and override
  `music_disk_uuid` too, or you write the live UUID onto a second filesystem and
  `/dev/disk/by-uuid` resolution becomes ambiguous.
- Address the disk by `/dev/disk/by-id` serial, never `/dev/nvmeXn1` — controller
  numbering is not stable across replugs.

**Mount**

- `mount.yaml` and `layout.yaml` both set `/mnt/music` to `2775`, across the mount
  boundary. Keep them equal, or every converge flip-flops the mode while still ending in
  the right state.
- `nofail` is not optional. Without it an unplugged enclosure drops `kvatch` into
  emergency mode at boot, and this host serves the household's DNS.
- Enrollment must precede `disk.yaml`; on a cold host the by-id path does not exist yet.
- `bolt` is static and D-Bus activated — `state: started`, never `enabled: true`. It needs
  `polkitd`, which the `bolt` package does not pull in. `boltctl forget` leaves an
  already-open tunnel authorized, so a working disk is not evidence that enrollment is
  stored; check `stored:` explicitly.

**Container**

- **Do not remove `ExecStartPre` from the CT 101 drop-in.** `RequiresMountsFor` alone does
  not block the start — measured, `systemctl start` returns 0 without it. Removing it
  restores the silent-failure bug while leaving a line that looks like it prevents it.
- The bind mount and feature flags go through `pct set`, not Terraform — `terraform@pve`
  gets a 403 on both. `terraform/modules/proxmox-lxc` needs its `ignore_changes` for
  `features` and `mount_point`, or the next apply plans to remove them, and removing
  `mount_point` forces a replacement of CT 101.
- Host ownership `100000:101500` is the unprivileged-LXC id shift of container
  `root:music`. Files look wrong from the Proxmox shell; that is correct. If the container
  sees `nobody:nogroup`, fix the host-side ownership.

**Backup**

- **Never let the rendered `docker-compose.yml` into the stack archive.** It carries six
  sops-managed credentials in cleartext and is regenerable from the template. Enforced
  twice — `--exclude`, then the script re-reads its own archive and aborts. Keep both.
- **Copy `museek.db` with `sqlite3 .backup`, never `cp`.** It is live SQLite; a plain copy
  can capture a torn page and still look like a file. The run must fail when
  `pragma integrity_check` is not `ok`.
- **Keep the repository off `/mnt/music`.** Same disk means it protects nothing.
- Retention is restic's own, inside the repository — this series is deliberately absent
  from `backup_prune_targets` in `homelab_backups`.
- Guard shell checks with `if`, not `cmd && fail` — under `set -euo pipefail` the latter
  misfires both ways.
- slskd's `data/*.db` are tarred hot, knowingly; see the local backlog.

After any change to this role, or any enclosure firmware update:

```bash
ssh root@192.168.1.101 'boltctl list | grep -E "status|stored"; findmnt /mnt/music'
```

Rationale, measurements and the restore drill are in the local notes for this role.
