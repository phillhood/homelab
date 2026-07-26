# pihole

Pi-hole v6 on a Debian LXC, layered on `debian_lxc_base`. The only resolver on the LAN.

## Usage

| Tag | Does |
|---|---|
| `install` | unattended installer, if `/usr/local/bin/pihole` is absent |
| `gravity` | seeds gravity from a Teleporter archive, fresh installs only |
| `config` | applies `pihole_config` and `pihole_local_records`, renders the lab wildcard |
| `password` | sets the web password |
| `pihole` | all four |

Settings are applied read-compare-set with `pihole-FTL --config <key> <value>`. Gravity and
adlists come from a Teleporter archive; there is no CLI for adlists in v6.

```bash
# force a password reset — it is not queryable, so it is otherwise only written on install
ansible-playbook playbooks/site.yaml --limit pihole --tags password \
  -e pihole_reset_password=true

# seed a rebuild from a captured archive
ansible-playbook playbooks/site.yaml --limit pihole \
  -e pihole_teleporter_archive=/abs/path/to/pi-hole_....zip
```

## Variables

| Variable | Default | Notes |
|---|---|---|
| `pihole_config` | `group_vars/pihole.yaml` | native YAML types — lists stay lists, numbers stay numbers |
| `pihole_local_records` | `group_vars/pihole.yaml` | every entry is load-bearing; see invariants |
| `pihole_reset_password` | `false` | |
| `pihole_teleporter_archive` | `""` | opt-in, fresh install only |
| `pihole_fresh_install` | `false` | `install.yaml` sets it, so `--tags gravity` works standalone |

**Requires** `pihole_web_password` from `pihole.sops.yaml`.

## Invariants

- **Never drop the empty-password assert in `password.yaml`.** `pihole setpassword` treats a
  blank first line on stdin as *remove the password* — it disables web authentication and
  exits 0, so the play would report success while leaving the interface open.
- **The password goes in on stdin, never as `argv`.** As an argument it sits in
  `/proc/<pid>/cmdline` for the life of the process, and `no_log` does nothing about the OS
  process table. This is mitigation, not elimination: Pi-hole's own `setFTLConfigValue`
  still passes it to `pihole-FTL` in argv, inside its own short-lived subprocess.
- **`pihole_config` must hold native YAML types.** `pihole-FTL --config` does not round-trip
  — it reads space-padded and unquoted (`[ 1.1.1.1, 1.0.0.1 ]`) but writes JSON
  (`["1.1.1.1","1.0.0.1"]`), and booleans read back lowercase while Jinja's `| string`
  renders them capitalised. `_set_key.yaml` constructs the expected *read* form from the
  desired value instead of parsing the actual one, and branches on booleans before the
  generic string fallback. Get either wrong and every converge re-sets the key and restarts
  DNS, forever.
- **Every entry in `pihole_local_records` is load-bearing.** Static-IP infrastructure never
  requests a DHCP lease, so nothing auto-registers it — those names exist only here, and
  dropping one silently breaks resolution for that host.
- **Do not run `pihole setpassword --help`.** There is no help flag, so it sets the password
  to the literal string `--help`. Read `/usr/local/bin/pihole` instead.
- Teleporter export is bare `--teleporter`; import is `--teleporter <file>`. There is no
  `import` subcommand, and a stray word there is read as the filename.
- After changing gravity or config, `pihole restartdns` before testing or a stale answer is
  served.

```bash
dig @192.168.1.100 doubleclick.net +short                # -> 0.0.0.0  (blocking)
dig @192.168.1.100 kvatch.{{ homelab_domain }} +short    # -> 192.168.1.101  (local record)
```

Rationale, the format-asymmetry derivation and the installer source: `.dev/docs/ansible/pihole.md`.
