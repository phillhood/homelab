# music_storage

Host-side role for the music SSD. Runs on `kvatch`, not in the container.

## What it does

- `thunderbolt.yaml` — installs `bolt` and enrolls the enclosure. **Runs first**; without
  it there is no block device at all.
- `disk.yaml` — the one destructive step. Partition + `mkfs.ext4`, behind four guards.
- `mount.yaml` — fstab entry by UUID, then mount.
- `layout.yaml` — `library/`, `downloads/{incomplete,complete}/`, `.state/museek/`, `.meta/`, owned
  `100000:101500`, mode `2775`.
- `container_mount.yaml` — `pct set` for `features` and `mp0`. Tagged `bindmount`,
  deliberately outside the `storage` tag.

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

`music_host_gid: 101500` here is the 100000-shifted form of the container-side
`music_gid` (defined in `inventory/group_vars/music.yaml`, defaulted again in
`music_stack` and `music_share`), not a value this role derives from it. **The two are
not wired together** — this role does not reference `music_gid` at all. Changing one
without the other leaves the host tree owned by a GID that no longer maps to `music`
inside the container.

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

`defaults,noatime,nofail,x-systemd.device-timeout=15`

`nofail` and the short device timeout are not optional on a hot-pluggable external disk —
without them an unplugged enclosure drops `kvatch` into emergency mode at boot instead of
booting. On Thunderbolt this matters more than it would on USB, because the disk is also
absent whenever enrollment has not been applied, not only when the cable is out.
`noatime` avoids a metadata write per file read.
