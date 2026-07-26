# debian_lxc_base

Minimal in-guest base for Debian 13 unprivileged LXCs. Configures **inside** the guest
only — network, IP and hostname belong to Terraform/cloud-init, never here.

## Usage

| Tag | Does |
|---|---|
| `packages` | installs `base_packages` — curl, ca-certificates, needrestart |
| `timezone` | sets the timezone from `homelab_timezone` |
| `health` | asserts no unexpected failed units, and that `systemd-sysctl` is active |
| `upgrade` | `apt dist-upgrade`. Tagged `never` — only runs when named explicitly |

## Variables

| Variable | Default | Notes |
|---|---|---|
| `base_packages` | curl, ca-certificates, needrestart | |
| `lxc_expected_failed_units` | `dev-mqueue.mount`, `run-lock.mount`, `tmp.mount` | the allowlist the health assert diffs against |
| `homelab_timezone` | `group_vars/all.yaml` | |

## Upgrading a guest's OS

`packages.yaml` uses `state: present` — it installs, it never upgrades, so a container sits
at whatever point release its template shipped until told otherwise. `upgrade.yaml` closes
that, and `apt dist-upgrade` has no undo: on `local-lvm` an LVM snapshot is the only way
back.

```bash
make snapshots                    # every container, its snapshots, thin-pool headroom
make snapshot   CT=104            # before upgrading
make unsnapshot CT=104            # after verifying — drops the revert path
make rollback   CT=104            # DESTRUCTIVE: stop, roll back, restart
```

`rollback` requires typing the container's hostname, and warns when `CT=100`.

**The procedure, one container at a time. Run each step separately and check it
succeeded** — a failed snapshot exits non-zero but will not stop a command that follows it
on the same line, and that mistake has been made here once.

```bash
make verify > /tmp/verify-before.txt                  # capture the before-state
make backup-pihole                                    # app-level backup, where relevant
make snapshot CT=100                                  # STOP HERE if this fails
cd ansible && uv run --project .. ansible-playbook playbooks/site.yaml \
  --limit pihole1 --tags upgrade
# verify, then one of:
make unsnapshot CT=100                                # keep the upgrade
make rollback   CT=100                                # undo it
```

**Order: `proxy1` → `registry1` → `forge1` → `music1` → `pihole1`.** Not alphabetical.
`pihole1` is last because it is the only container whose failure removes all LAN DNS, so
the mechanism gets proved four times where a mistake is cheap first.

### CT 101 `music` cannot be snapshotted at all

`pct snapshot 101` fails with `snapshot feature is not available` — it is the only guest
with a host-path bind mount (`mp0: /mnt/music,mp=/srv/music`), and Proxmox cannot snapshot
a host directory. `make snapshot CT=101` refuses before attempting rather than passing
PVE's terse error through where it could be read as success.

**What protects CT 101 instead:**

| Covered | By |
|---|---|
| The library, and everything else under `/mnt/music` | `make backup-music-content` — restic, daily timer, repo on pve-root rather than the library's own disk |
| museek's `museek.db` | `make backup-music-content` — staged with `sqlite3 .backup` and integrity-checked, not copied |
| slskd's config and data (`/opt/music-stack`) | `make backup-music-content` — tarred **hot**, and only while CT 101 is running |
| Syncthing identity — `config.xml`, `key.pem`, `cert.pem` — and `smb.conf` | `make backup-music` |
| The rest of the guest | reproducible by Ansible |

For a genuine pre-upgrade revert point use `vzdump`, which skips bind mounts and captures
the rootfs only. That path has **not** been exercised here, and it suspends or stops the
container rather than freezing it.

## Invariants

- **The `never` tag on `upgrade` is load-bearing.** Without it every `make apply` triggers a
  multi-hundred-package upgrade across the fleet mid-converge. For the same reason, never
  put a role tag on a `never`-tagged task — naming any of its tags activates it.
- **`pct snapshot` works on a running container; `pct rollback` does not.** Reverting costs
  a stop.
- **This role will not reboot, deliberately.** `upgrade.yaml` reports
  `/var/run/reboot-required` and stops. Rebooting CT 100 is a *total* LAN DNS outage for
  10–20s: OPNsense advertises DHCP option 6 as the single value `192.168.1.100`, and its own
  dnsmasq listens on `53053` so it cannot stand in.
- **Do not "fix" that by adding a public resolver as a secondary.** Clients round-robin
  across the list, so ad filtering would leak intermittently instead of failing cleanly. The
  real answer is a second Pi-hole.
- **Never widen `lxc_expected_failed_units` to silence a failure.** It is a tripwire; if the
  `health` tag fails after a systemd upgrade, that is it working. Read the units it names
  and adjust deliberately. Override per group in `inventory/group_vars/`, never in this
  role's defaults — widening the baseline blinds every container at once.
- Both `command` tasks in `health.yaml` need `check_mode: false`, or `--check` skips them
  and the asserts fail on an undefined `stdout`.
- Drop snapshots once an upgrade is verified. They grow as blocks diverge on thin storage
  and there is no pool-exhaustion alerting (`.dev/docs/backlog.md`).

Prove the health assert still bites by dropping one unit from the allowlist:

```bash
ansible-playbook playbooks/site.yaml --limit lxc --tags health \
  -e '{"lxc_expected_failed_units":["dev-mqueue.mount","run-lock.mount"]}'
```

That must fail with `Unexpected failed systemd units: tmp.mount`. If it passes, the assert
has become vacuous.

Debian 13 ships no `/etc/timezone` — check with `readlink -f /etc/localtime`, not
`cat /etc/timezone`.

Rationale, the intentionally-disabled container features, and the nesting observation:
`.dev/docs/ansible/debian_lxc_base.md`.
