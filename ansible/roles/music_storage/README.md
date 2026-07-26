# music_storage

Everything about the music disk on the host: the SSD itself, its layout, the bind mount
into CT 101, and the content backup that protects it. Runs on `kvatch`, not in the
container.

## What it does

- `thunderbolt.yaml` — installs `bolt` and enrolls the enclosure. **Runs first**; without
  it there is no block device at all.
- `disk.yaml` — the one destructive step. Partition + `mkfs.ext4`, behind four guards.
- `mount.yaml` — fstab entry by UUID, then mount.
- `layout.yaml` — `library/`, `downloads/{incomplete,complete}/`, `.state/museek/`, `.meta/`, owned
  `100000:101500`, mode `2775`.
- `container_mount.yaml` — `pct set` for `features` and `mp0`. Tagged `bindmount`,
  deliberately outside the `storage` tag.
- `backup.yaml` — restic, the repository, `/usr/local/sbin/music-backup`, and the timer
  that runs it. Tagged `musicbackup`.

## Content backup

restic repository at `/var/backups/restic/music` on `kvatch`, plus a daily timer. Built by
`backup.yaml`; the script it installs is the single implementation, and
`homelab_backups` runs that same script rather than reimplementing it.

```bash
make backup-music-content                      # run now
make music-snapshots                           # what is held
make music-restore DEST=/var/tmp/restore-test  # add SNAPSHOT=<id> for an older one
```

`make backup-music` is a different thing — a manifest of path/size/mtime, not the files.

Variables worth setting live in `defaults/main.yaml`: `music_backup_repo`,
`music_backup_excludes`, `music_backup_stack_excludes`, the three `keep_*` retention
counts, and `music_backup_on_calendar`.

**Requires** `restic_repo_password`, from `group_vars/proxmox.sops.yaml`.

### Invariants

- **Never let the rendered `docker-compose.yml` into the stack archive.** It carries six
  sops-managed credentials in cleartext and is regenerable from the template. Enforced
  twice — `--exclude`, then the script re-reads its own archive and aborts. Keep both.
- **Copy `museek.db` with `sqlite3 .backup`, never `cp`.** It is live SQLite; a plain copy
  can capture a torn page and still look like a file. The run must fail when
  `pragma integrity_check` is not `ok`.
- **Keep the repository off `/mnt/music`.** It sits on pve-root (nvme1n1) precisely because
  the library is on nvme0n1; same disk means it protects nothing.
- Retention is restic's own, inside the repository — this series is deliberately absent
  from `backup_prune_targets` in `homelab_backups`.
- Guard shell checks with `if`, not `cmd && fail` — under `set -euo pipefail` the latter
  misfires both ways.
- slskd's `data/*.db` are tarred hot, knowingly; see `.dev/docs/backlog.md`.

Rationale, measurements and the restore drill: `.dev/docs/ansible/music_storage.md`.

## Thunderbolt, not USB

The design spec assumed this enclosure would run over USB-C. It does not — plugged into
`kvatch` the ACASIS TBU401Pro negotiates Thunderbolt 3 at 40 Gb/s, and the disk presents
as a **native NVMe device**, so paths are `/dev/disk/by-id/nvme-*`.

The host's TB domain security level is `user`, which means an unenrolled device produces
no block device whatsoever — not a degraded one, none. `thunderbolt.yaml` installs `bolt`
and enrolls the enclosure by its TB UUID with `--policy auto`.

It also installs **`polkitd`**, which is easy to miss: the `bolt` package depends only on
the polkit client library, but `boltctl enroll` calls the polkit *daemon* over D-Bus, and
Proxmox's minimal Debian base has no daemon installed. Without it, enrollment fails with
`org.freedesktop.DBus.Error.ServiceUnknown` even as root.

Note that `boltctl forget` removes the stored record but leaves an already-open tunnel
authorized. The disk keeps working until the next disconnect, then vanishes — so a
"working" disk is not evidence that enrollment is stored. Check `stored:` explicitly.

`bolt` is a **static, D-Bus/udev-activated unit**. It takes `state: started` but not
`enabled: true` — enabling a static unit fails. Boot-time re-authorization comes from udev
activation acting on the stored policy record.

That last point is the failure mode to watch. If enrollment does not survive a reboot,
`nofail` means the host boots perfectly with the library silently absent. After any change
to this role, or any firmware update, re-verify:

```bash
ssh root@192.168.1.101 'boltctl list | grep -E "status|stored"; findmnt /mnt/music'
```

Because the transport is Thunderbolt rather than USB, three risks in the design spec's
§12 table no longer apply: TRIM passes through, SMART needs no `-d sat`, and UAS quirks
are impossible.

## The four format guards

1. The disk is addressed by `/dev/disk/by-id` serial, never `/dev/nvmeXn1` — controller
   numbering is not stable across replugs.
2. An existing ext4 filesystem labelled `music` makes the role **refuse** to format.
   This is what makes re-runs safe after day one.
3. `music_format_disk` defaults to `false`; formatting needs `-e music_format_disk=true`.
4. If the partition device exists but `blkid` cannot read it, the role **refuses**
   rather than treating an unreadable signature as a blank disk.

Guard 4 exists because `blkid` runs with `failed_when: false`, which it must — a
genuinely new disk has no partition device and `blkid` legitimately fails there. Without
guard 4 that fail-open path is indistinguishable from `blkid` erroring on a *present*
filesystem, which on a Thunderbolt-attached disk is not hypothetical. The `stat` on the
partition device is what separates the two cases: no device means new disk, device
present plus a read error means stop.

## The mkfs options reproduce the original decisions

`opts: "-L {{ music_fs_label }} -m 0 -i {{ music_fs_inode_ratio }} -U {{ music_disk_uuid }}"`.

**`-i 1048576` is the one that cannot be undone.** ext4's inode count is fixed at format
time — not changeable by `tune2fs`, not by `resize2fs`. The default ratio of one inode per
16 KiB is tuned for a root filesystem full of small files; on a 2 TB media disk it
allocates ~122 million inodes costing **29 GiB of inode tables on an empty filesystem**.
One per MiB gives ~1.9 million inodes for ~466 MiB, still far more than a library of
FLACs or MP3s will ever need. If this role ever formats a replacement disk without that
flag, the 29 GiB is silently gone and only another reformat gets it back.

`-U` reuses the UUID already recorded in `host_vars`, so a replacement disk drops in
without updating fstab, the inventory, or anything else that references it.

Guard 4 has one deliberate cost. If a first-time provision is interrupted between
`parted` and `mkfs` — partition created, never formatted — a retry now **refuses**,
because the partition device exists and `blkid` finds no signature on it. Previously
that retry would have resumed and formatted. This is a fail-closed regression in a rare
path, chosen knowingly: the alternative is an unreadable-but-present device being
treated as blank, which is the failure that costs the library. To resume an interrupted
provision, confirm the partition really is empty and then wipe it (`wipefs -a`) so the
device is genuinely absent of signatures before re-running.

To test changes to these guards safely, use a scratch loopback device rather than the
real disk — `losetup` an image with no filesystem gives a real device node and a
legitimately failing `blkid`, exercising the same branch at no risk:

```bash
truncate -s 64M /tmp/guard-test.img && losetup -f --show /tmp/guard-test.img
ansible-playbook playbooks/music.yaml --tags disk \
  -e music_disk_partition=/dev/loop0 \
  -e music_disk_uuid="$(uuidgen)" \
  -e music_format_disk=true
```

**Overriding `music_disk_uuid` is not optional.** `disk.yaml` passes
`-U {{ music_disk_uuid }}` to `mkfs`, and that variable is pinned in `host_vars` to the
real library disk. Overriding only the partition would format the loop device with the
*live disk's UUID*, giving one host two filesystems claiming the same UUID — after which
`/dev/disk/by-uuid` resolution is ambiguous and a later `mount -a` or reboot could mount
the empty test image at `/mnt/music`. That is precisely the silent failure these guards
exist to prevent.

Guard 2 is the one that matters. Without it an innocent re-run reformats the library.
Prove it still bites:

```bash
ansible-playbook playbooks/music.yaml --tags disk -e music_format_disk=true
```

That must **fail**. If it passes, the guard has become vacuous.

## Why the bind mount is here and not in Terraform

Proxmox reserves bind mounts and container feature flags for `root@pam`. The scoped
`terraform@pve` token gets a 403 — the same 403 recorded in
`roles/debian_lxc_base/README.md`. Putting a `features` variable on the Terraform module
would be code for a call that always gets refused, so both settings go through
`pct set` over SSH instead.

The Terraform side needs a matching guard, or the provider undoes what this role just
did. `terraform/modules/proxmox-lxc` carries an `ignore_changes` for `features` and
`mount_point` for exactly this reason — without it, the next `terraform apply` sees
attributes the configuration does not declare and plans to remove them, and removing
`mount_point` forces a replacement of CT 101. See `terraform/modules/proxmox-lxc/README.md`
for the measured plan output.

## Why the mount point is 2775 in two places

`mount.yaml` creates `/mnt/music` with mode `2775` and `layout.yaml` sets the same path
to `2775` with ownership. That looks redundant but is not: before the mount, the path is
an ordinary directory; after it, the identical path resolves to the **ext4 root inode**.
Two tasks therefore manage one path across a boundary that Ansible cannot see.

If their modes disagree, every converge reports `changed=2` and flip-flops the mode,
while still ending in the right state — the failure mode that looks like success until
`make idempotent` catches it. Keep the two values equal. If you change one, change both.

## Why 100000:101500 looks wrong

An unprivileged LXC shifts IDs by 100000, so container `root:music` (0:1500) is host
`100000:101500`. Files look wrong from the Proxmox shell; that is correct. Host root
bypasses it, so manual management from the host works normally.

If the container sees `nobody:nogroup`, the host-side ownership is what to fix.

`music_gid: 1500` lives in `inventory/group_vars/music_common.yaml`, a group both
`kvatch` and `music1` belong to — `kvatch` cannot see `group_vars/music.yaml`, which
applies only to the `music` group (CT 101), so the shared constant has to sit one level
up, in a group that reaches both sides of the bind mount. `music_container_mount` and
`music_stack_dir` are there for the same reason. `music_stack` and `music_share` still
default their own copy for standalone runs, but on `music1` the `music_common` group var
wins.

`music_host_gid` here derives from it: `"{{ 100000 + music_gid | int }}"`. The shift is
not arithmetic for its own sake — it is the same unprivileged-LXC mapping described
above, applied to whatever GID the container actually uses, so a change to `music_gid`
changes the host-side ownership target in the same place, in the same run. Change
`music_gid` in `music_common.yaml` and both sides move together; `music_host_uid` stays
a plain `100000` because it is the container's `root`, not a shift of anything defined
in `music_common`.

## Run order on first build

The bind mount needs both the host directory and the container to exist:

```bash
ansible-playbook playbooks/music.yaml --tags storage   # TB enroll + disk + layout
terraform -chdir=terraform/environments/kvatch apply   # create CT 101
ansible-playbook playbooks/music.yaml --tags bindmount # attach, reboot CT
ansible-playbook playbooks/music.yaml                  # everything
```

The `storage` tag covers `thunderbolt` as well, and the ordering inside
`tasks/main.yaml` is load-bearing: enrollment must precede `disk.yaml`, or the by-id
path does not exist yet on a cold host.

Afterwards the whole playbook runs in one pass. `container_mount.yaml` no-ops with a
message when CT 101 does not exist yet, so a full run stays green before Terraform.

## fstab options

`defaults,noatime,nofail,x-systemd.device-timeout={{ music_device_timeout }}` — 60 by default.

`nofail` is not optional on a hot-pluggable external disk — without it an unplugged
enclosure drops `kvatch` into emergency mode at boot instead of booting, and this host
serves the household's DNS. On Thunderbolt this matters more than it would on USB, because
the disk is also absent whenever enrollment has not been applied, not only when the cable
is out. `noatime` avoids a metadata write per file read.

The timeout was raised from 15 s to 60 s once CT 101 stopped depending on a fast boot
(below). `boltd` is `Type=dbus` and `static`, so it cannot be enabled to run earlier — it
is activated on demand, and how quickly it authorises the tunnel on a cold boot is a race
nobody controls. Waiting longer is now free.

## CT 101 refuses to start unless the disk is really mounted

`nofail` means a missing disk is **silent**: the host boots clean, `/mnt/music` is an empty
directory, and nothing is marked failed. Without a guard, CT 101 then starts against that
empty directory — museek writes into `kvatch`'s root filesystem, and Syncthing, which is
Send Only from the NAS, sees an empty library. That is the worst failure shape in this
design, because everything looks healthy.

`container_mount.yaml` therefore drops in
`/etc/systemd/system/pve-container@101.service.d/require-music-mount.conf`:

```ini
[Unit]
RequiresMountsFor=/mnt/music

[Service]
ExecStartPre=/usr/bin/mountpoint -q /mnt/music
```

Mount present, container starts normally. Mount absent, the container **refuses to start**
and says why:

```
Active: failed (Result: exit-code)
Process: ExecStartPre=/usr/bin/mountpoint -q /mnt/music (code=exited, status=32)
```

Both `systemctl start` and `pct start` are blocked — PVE's tooling shells out to systemd, so
there is no bypass. Recovery is `pct start 101` once the disk is back.

### `RequiresMountsFor` alone does NOT block — do not remove the ExecStartPre

This was measured, not assumed, and the obvious "simplification" is wrong.

`RequiresMountsFor` expands into `Requires=` and `After=` on `mnt-music.mount`, and
`systemctl show` confirms both are present. It still does not prevent the start. Tested
against a standalone probe unit with the mount stopped **and masked**, with and without
`DefaultDependencies=no`: `systemctl start` returned **exit 0** every time. The journal
shows the container starting first and the mount being pulled in a second later.

`RequiresMountsFor` is kept because it is the correct ordering declaration and it usefully
*repairs* the common case — if the device is present but simply unmounted, starting the
container mounts it first. `ExecStartPre` is what actually enforces the invariant. Removing
it restores the silent-failure bug while leaving a line that looks like it prevents it.
