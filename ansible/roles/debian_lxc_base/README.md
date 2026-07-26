# debian_lxc_base

Minimal in-guest base for Debian 13 unprivileged LXCs. Configures **inside** the
guest only — network, IP, and hostname belong to Terraform/cloud-init (the layer
below), never here.

## What it does

- Installs `base_packages` (curl, ca-certificates).
- Sets the timezone from `homelab_timezone`.
- **Verifies the negatives** (below) via `health.yaml` asserts.

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
