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

**Nesting eliminates the three failed mount units — it does not merely shift them.**
Measured on identical Debian 13 templates on the same host:

| Container | Features | Failed units |
|---|---|---|
| CT 100 `pihole` | none | 3 — `dev-mqueue.mount`, `run-lock.mount`, `tmp.mount` |
| CT 101 `music` | `nesting=1,keyctl=1` | 0 |

So `music` needs **no** `lxc_expected_failed_units` override. The role's default
allowlist is a superset of what this container actually fails, and the assert still
bites on anything new. This also qualifies the "no mount-unit masking" negative above:
those failures are a consequence of running without nesting, not an inherent property
of unprivileged LXC.

If a future nesting container does fail a different set, override
`lxc_expected_failed_units` per group in `inventory/group_vars/`, never in this role's
defaults — widening the baseline would blind every container at once.
