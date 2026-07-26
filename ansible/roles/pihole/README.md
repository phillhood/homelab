# pihole

Installs and configures Pi-hole v6 on a Debian LXC, layered on `debian_lxc_base`.

## Config model (capture-then-codify)

- **Source of truth** captured from the live host into `.dev/pihole-capture/`.
- **Settings** (upstreams, reverse servers, rate limit, privacy, local DNS records)
  applied idempotently with `pihole-FTL --config <key> <value>` (read-compare-set).
- **Gravity / adlists** seeded from a Teleporter archive on fresh installs; refresh
  via `pihole -g`.
- **Password** set with `pihole setpassword` from `pihole.sops.yaml` (`no_log`).

## The read/write format asymmetry

`pihole-FTL --config` does not round-trip. It **reads** space-padded and unquoted but
**writes** JSON:

| | Form |
|---|---|
| read | `[ 1.1.1.1, 1.0.0.1 ]` |
| write | `["1.1.1.1","1.0.0.1"]` |
| empty | `[]` both ways |

So a naive read-vs-write-value comparison never matches, and every run would re-set
every list key and restart DNS. `_set_key.yaml` therefore **constructs** the expected
read-form from the desired value rather than parsing the actual one.

Parsing is not an option: `dns.revServers`' single element contains commas
(`true,192.168.1.0/24,192.168.1.1,home`), making a one-element list indistinguishable
from a four-element one.

Because of this, `pihole_config` holds **native YAML types** (lists stay lists, numbers
stay numbers) — both forms are derived from them.

### Booleans are a third form, not a variant of the generic one

`pihole-FTL` **reads** a boolean back lowercase (`true`/`false`), but Jinja's `| string`
filter renders a Python/YAML boolean as `True`/`False` — capitalized. Left to the
generic fallback, the read-form comparison would never match a boolean key, so every
converge would re-`--config` it and restart DNS, forever. `_set_key.yaml` therefore
branches on `cfg_item.value is boolean` **before** the generic string fallback, in
**both** `_cfg_read_form` and `_cfg_write_form` — the same "construct the expected
read-form" pattern as the list case above, just for a different type. `misc.etc_dnsmasq_d`
(added in the tier0 build) was the first boolean key this role ever set; without the
`is boolean` branch it would have been the first key that never reported idempotent.

## dns.hosts holds infra records that nothing else provides

Static-IP infrastructure never requests a DHCP lease, so nothing auto-registers it.
Those names live only here. Every entry in `pihole_local_records` is load-bearing:
dropping any one of them silently breaks name resolution for that host — this list has
already grown twice since the role was written, so treat the file itself as the count,
not a number restated here.

## Teleporter

- **Export:** bare `pihole-FTL --teleporter` writes `pi-hole_<host>_teleporter_<ts>.zip`
  into the working directory.
- **Import:** `pihole-FTL --teleporter <file>`. There is no `import` subcommand — a
  stray word there is read as the filename.
- The archive carries `pihole.toml`, `hosts`, `dhcp.leases`, `gravity.db` and
  `pihole-FTL.db`.

Seeding is opt-in and only runs on a fresh install. `pihole_teleporter_archive` stays
empty by default because the captured archive lives under gitignored `.dev/` and is
timestamped, so it would not survive a clone. Pass it during a rebuild:

```bash
ansible-playbook playbooks/site.yaml --limit pihole \
  -e pihole_teleporter_archive=/abs/path/to/pi-hole_....zip
```

## Adlists

`dns.adlists` is **not** a `pihole.toml` key, and there is no `pihole adlist` CLI —
v6 keeps adlists in `gravity.db`. They arrive with the Teleporter seed. If explicit
enforcement is ever needed, use the HTTP API; `pihole_adlists` is currently unused.

## Re-run semantics

Idempotent except a deliberate `pihole -g`. Force a password reset with
`-e pihole_reset_password=true` — the password is not queryable, so it is only written
on a fresh install or on that explicit flag.

`pihole_fresh_install` defaults to `false` so that `--tags gravity` or `--tags password`
work standalone; `install.yaml` overrides it when that tag runs.

## Cache gotcha

After changing gravity or config, `pihole restartdns` before testing or a stale answer
is served.

```bash
dig @192.168.1.100 doubleclick.net +short   # -> 0.0.0.0  (blocking)
dig @192.168.1.100 kvatch.home +short       # -> 192.168.1.101  (local record)
```
