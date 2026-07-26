# debian_lxc_base

Minimal in-guest base for Debian 13 unprivileged LXCs. Configures **inside** the
guest only — network, IP, and hostname belong to Terraform/cloud-init (the layer
below), never here.

## What it does

- Installs `base_packages` (curl, ca-certificates).
- Sets the timezone from `homelab_timezone`.
- **Verifies the negatives** (below) via `health.yaml` asserts.
- Provides an **opt-in** OS upgrade path (below) that never fires automatically.

## Upgrading a guest's OS

`packages.yaml` uses `state: present`. It installs, it never upgrades — so a container sits
at whatever point release its template shipped until told otherwise. As of 2026-07-26 all
five guests reported Debian 13.1 while stable was 13.6, with 67 packages pending on
`pihole1`, 16 of them from `stable-security`.

`upgrade.yaml` closes that, tagged so it cannot run by accident:

```yaml
- name: Upgrade all packages
  ansible.builtin.import_tasks: upgrade.yaml
  tags: [upgrade, never]
```

**The `never` tag is load-bearing.** Without it every `make apply` would trigger a
multi-hundred-package upgrade across the whole fleet mid-converge. Verified with
`ansible-playbook playbooks/site.yaml --list-tasks`: the upgrade tasks are absent unless
`--tags upgrade` names them explicitly.

### `apt dist-upgrade` has no undo — the snapshot is the revert path

There is no "downgrade everything". All five guests are on `local-lvm` (lvmthin), so an LVM
snapshot is the only real way back, and the Makefile wraps it:

```bash
make snapshots                    # every container, its snapshots, thin-pool headroom
make snapshot   CT=104            # before upgrading
make unsnapshot CT=104            # after verifying — drops the revert path
make rollback   CT=104            # DESTRUCTIVE: stop, roll back, restart
```

`rollback` requires typing the container's hostname to confirm, and warns explicitly when
`CT=100`, because rolling Pi-hole back takes all LAN DNS down for the duration.

**`pct snapshot` works on a running container; `pct rollback` does not.** Reverting costs a
stop — acceptable, since you would only revert if the service was already broken.

Snapshots on thin storage grow as blocks diverge, and there is no pool-exhaustion alerting
(`.dev/docs/backlog.md`). Drop them once the upgrade is verified rather than leaving them.

### The procedure, per container

```bash
make verify > /tmp/verify-before.txt                   # capture the before-state
make backup-pihole                                    # app-level backup, where relevant
make snapshot CT=100                                  # the actual revert path
cd ansible && uv run --project .. ansible-playbook playbooks/site.yaml \
  --limit pihole1 --tags upgrade
# verify, then one of:
make unsnapshot CT=100                                # keep the upgrade
make rollback   CT=100                                # undo it
```

### Upgrade in this order, not alphabetically

`pihole1` is **last**. It is the only container whose failure removes all LAN DNS, so the
mechanism gets proved where a mistake is cheap:

`proxy1` → `registry1` → `forge1` → `music1` → `pihole1`

`proxy1` is 1 core / 512 MB with nothing depending on it. `registry1` holds only a
pull-through cache. By the time Pi-hole is reached the task has run four times.

### The role will not reboot, deliberately

`upgrade.yaml` reports `/var/run/reboot-required` and stops there.

The upgrade itself should be invisible to DNS: `pihole-FTL` is **not** an apt package — the
Pi-hole installer ships its own systemd unit — so `apt dist-upgrade` will not restart the
resolver as a side effect. Only the systemd bump really wants a reboot to land fully, and
that is a 10-20 second outage.

**That outage is total, and this was measured.** OPNsense advertises DHCP option 6 as a
single value:

```
type: set   option: 6   value: 192.168.1.100   force: 0
```

There is no secondary resolver, and OPNsense's own dnsmasq listens on port **53053**, so it
cannot stand in. Every DHCP client fails lookups for the duration of a CT 100 reboot.

Do not "fix" this by adding a public resolver as a secondary — clients round-robin across
the list, so ad filtering would leak intermittently instead of failing cleanly. The real
answer is a second Pi-hole.

### Recreating is not upgrading

A Debian point release is a label for a set of package versions, not a distinct OS.
`base-files` is the package that writes `/etc/debian_version` (`13.8+deb13u1` →
`13.8+deb13u6` is exactly 13.1 → 13.6), so `apt dist-upgrade` reaches the same versions a
fresh template would. Rebuilding a container from a newer template gets you a clean rootfs
and nothing newer — while costing whatever the guest holds that Ansible does not reproduce.
See `terraform/modules/proxmox-lxc/README.md`.

### Expect the failed-unit assert to fire after a systemd upgrade

`lxc_expected_failed_units` is the tripwire for exactly this. If the `health` tag fails
after an upgrade, that is the assert working. Read the units it names and adjust the list
deliberately — never widen it to silence it.

## The negatives — intentionally OFF (from Pi-hole LXC build notes)

- **No `nesting`.** The "Systemd 257 detected… enable nesting" message is a
  host-side heuristic, not an observed failure. Running nesting-off and observing.
  Security delta on an *unprivileged* container is modest and does not breach
  uid-mapping isolation. Enable only on evidence: `pct set <id> -features nesting=1`
  (root@pam only — the API token can't set feature flags; that's the 403 we hit).
- **No `lxc.generator`.** The systemd-256 `243/CREDENTIALS` issue is absent on the
  current template (verified: `systemd-sysctl` active). The generator workaround is
  not needed.
- **No mount-unit masking.** Failed `dev-mqueue`/`run-lock`/`tmp` units are cosmetic;
  `/tmp` is writable. Masking `tmp.mount` breaks the Pi-hole installer's `/tmp` staging.
  See "The nesting exception" below — CT 101 does not exhibit these at all.

If `health.yaml` ever fails, revisit these — the asserts are the tripwire.

## How the failed-unit assert works

An unprivileged container always reports those three mount units as failed, so
asserting "zero failed units" would fail on a correctly-configured guest. Instead
`lxc_expected_failed_units` (in `defaults/main.yaml`) allowlists them, and the assert
fires only on units outside that list — so a genuinely new failure is caught while the
documented baseline passes.

Verify the assert still bites after changing it by dropping one unit from the list:

```bash
ansible-playbook playbooks/site.yaml --limit lxc --tags health \
  -e '{"lxc_expected_failed_units":["dev-mqueue.mount","run-lock.mount"]}'
```

That must fail with `Unexpected failed systemd units: tmp.mount`. If it passes, the
assert has become vacuous.

## Notes on verification commands

Debian 13 no longer ships `/etc/timezone`. Check the timezone with
`readlink -f /etc/localtime` (expect `/usr/share/zoneinfo/America/Toronto`) or
`date +%Z%z`, not `cat /etc/timezone`.

Both `command` tasks in `health.yaml` carry `check_mode: false`, because `--check`
otherwise skips them and the asserts fail on undefined `stdout`.

## The nesting exception

CT 101 `music` is the deliberate exception to the "no nesting" negative above. It runs
Docker, which needs `nesting=1` and `keyctl=1`. Those flags are set by
`music_storage/tasks/container_mount.yaml` via `pct set`, not by this role and not by
Terraform — the API token gets a 403 on feature flags.

**Observed**, same Debian 13 template, same host:

| Container | Features | Failed units |
|---|---|---|
| CT 100 `pihole` | none | 3 — `dev-mqueue.mount`, `run-lock.mount`, `tmp.mount` |
| CT 101 `music` | `nesting=1,keyctl=1` | 0 |

**Not established: which flag is responsible.** Both were enabled together, so this is
one paired observation with two variables changed at once. It does not show that
`nesting=1` alone is sufficient, and the negatives above should not be read as
overturned. To isolate it: `pct set 101 -features nesting=1`, reboot, re-check. Nobody
has done that.

What follows regardless of the cause: `music` needs **no** `lxc_expected_failed_units`
override. The role's default allowlist is a superset of what this container actually
fails, and a superset does not weaken the assert — `health.yaml` diffs the *actually
failing* units against the allowlist, so entries that never fire suppress nothing and
any genuinely new failure still trips it.

If a future container does fail a different set, override `lxc_expected_failed_units`
per group in `inventory/group_vars/`, never in this role's defaults — widening the
baseline would blind every container at once.
