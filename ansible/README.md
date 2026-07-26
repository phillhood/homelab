# ansible

Configures the homelab guests and the Proxmox host. Terraform provisions; Ansible
configures what Terraform created; nothing here creates or destroys guests.

Run everything through the repo-root `Makefile` — `make help` lists the targets.

## Playbooks

| Playbook | Purpose | Success signal |
| --- | --- | --- |
| `site.yaml` | Converge the homelab — imports `music.yaml` and `tier0.yaml` | **`changed=0`** on a second run |
| `music.yaml` | Music NAS: host storage, then share + stack on `music` | imported by `site.yaml`; runnable alone |
| `tier0.yaml` | `registry` → `proxy` → `forge`, in that order | imported by `site.yaml`; runnable alone |
| `backups.yaml` | Every backup series — Pi-hole, OPNsense, music, Forgejo, Terraform state | **`changed` every run, by design** |

`music.yaml` and `tier0.yaml` are imported by `site.yaml` rather than being separate entry
points, so a full converge covers everything. Run them directly to scope work to one area.
`tier0.yaml`'s play order is deliberate: the registry and proxy exist before the forge that
sits behind the proxy.

They are separate deliberately. Backups are `changed` on every run — a backup that never
changes is broken — so folding them into `site.yaml` would destroy its `changed=0`
signal, which is the property everything else is verified against.

## Roles

| Role | Group | Notes |
| --- | --- | --- |
| `proxmox_host` | `proxmox` | repos, resolver, root keys, Terraform account + SOPS token, thin-pool reclaim |
| `pve_templates` | `proxmox` | LXC + cloud-init VM templates |
| `debian_lxc_base` | `lxc` | packages, timezone, health asserts, opt-in OS upgrade |
| `pihole` | `pihole` | install, config, gravity, password |
| `music_storage` | `proxmox` | Thunderbolt SSD, ext4, host mount, layout, bind mount into CT 101, restic content backup + timer |
| `music_share` | `music` | Samba + Syncthing |
| `music_stack` | `music` | Docker, slskd, museek, museek-discord |
| `registry` | `registry` | Zot pull-through cache |
| `proxy` | `proxy` | Caddy, wildcard TLS via Cloudflare DNS-01 |
| `postgresql` | `forge` | host-agnostic Postgres on a Unix socket |
| `forgejo` | `forge` | Forgejo + its OCI registry |
| `homelab_backups` | `pihole`, `music`, `proxmox`, `forge`, `opnsense`, `localhost` | every backup series into `.dev/`, plus the music content run on `kvatch` |

Each role has its own README: what it does, how to run it, the variables worth setting,
and an **Invariants** list. Read the invariants before changing a role — each one is a
trap that cost real time to find, and several describe a change that looks like a
simplification and is not.

## Conventions

- Role names use underscores. `tasks/main.yaml` is a thin tagged dispatcher, so
  `--tags <concern>` runs one slice.
- Every role carries a tag matching its own name, so `--tags forgejo` or
  `--tags proxmox_host` runs that role and nothing else. Multi-word *concern* tags are
  hyphenated (`bind-mount`, `ssh-keys`, `music-backup`); role tags keep the role's
  underscores. **Never put a role tag on a `never`-tagged task** — naming any tag on a
  `never` task activates it, so `fstrim` carries only `[fstrim, never]`. A role tag there
  would make `--tags proxmox_host` trigger thin-pool reclaim across every container.
- **No explanatory comments in config.** Task names state what the task does; rationale
  goes in documentation. That applies to task names, play names and assert messages too —
  no parenthetical asides.
- **Role READMEs are reference plus invariants, not narrative.** What the role does, how
  to run it, the variables worth setting, what it requires but does not default, and a
  terse `## Invariants` list — one line per trap, no measurement stories. Rationale,
  history and the how-we-found-it write-ups go in `.dev/docs/ansible/<role>.md`.
  Invariants stay in the README on purpose: `.dev/` is gitignored, and an invariant that
  does not survive a clone is not protecting anything.
- Variables live in exactly one layer. Role `defaults/` owns the role's own values;
  `group_vars/` carries only what is environment-specific — versions, checksums,
  addresses, identities, secrets — or a genuine override. A value repeated in both means
  editing the default silently does nothing. The exception is `music_common.yaml`, whose
  three variables are deliberately shared across the bind mount by `kvatch` and `music1`.
- Secrets rule: *would leaking this let someone in?* If yes it goes in a `*.sops.yaml`;
  if no it stays plaintext. Public keys and device IDs are not secrets.
- `vars_plugins_enabled` includes `community.sops.sops`, so any inventory read — including
  `make vars` — decrypts every `*.sops.yaml`. `make vars` masks those values by default;
  the key list comes from the top-level keys of `inventory/group_vars/*.sops.yaml` at run
  time, so a new secret is covered automatically without editing the Makefile. Pass
  `SHOW_SECRETS=1` to see the real values.
- Any read-only `command` whose output a later task consumes needs `check_mode: false`,
  or `--check` skips it and the dependent guard breaks.

## Lint

`make lint` runs syntax checks plus `ansible-lint`. Two rules are skipped in
`.ansible-lint`, both deliberately:

**`command-instead-of-module`** — the flagged tasks are `systemctl --failed` and
`systemctl is-active` in `debian_lxc_base`, which are read-only *enumerations* the
`systemd` module cannot express, and Pi-hole's `curl | bash` installer, which is the
upstream-documented install method.

**`var-naming[no-role-prefix]`** — the rule wants every role variable prefixed with the
full role name (`debian_lxc_base_base_packages`). These roles are private and never
published, the variables already carry meaningful namespaces (`pve_`, `lxc_`, `backup_`,
`zot_`, `caddy_`), and the prefixed forms read materially worse.

The collision this rule guards against does exist here: `music_share` and `music_stack`
both run on `music1` and both declare `music_gid` and `music_container_mount`. That is
deliberate, and it is why `inventory/group_vars/music_common.yaml` exists — the group var
is the shared truth for both sides of the bind mount, and the role defaults are
standalone-run fallbacks that it overrides. The sharing is centralised and visible rather
than accidental, which is the property the rule is a proxy for.

Revisit if a role is ever published, or if two roles ever pick *different* names for the
same value — that happened once, with `backup_music_script` against `music_backup_script`,
and a role prefix would not have caught it either. The real guard is one definition per
value, which the Conventions section above states directly.

## Toolchain

`ansible-core`, `ansible-lint` and `jmespath` are pinned in the repo-root
`pyproject.toml` and locked in `uv.lock`. Everything runs through `uv run`, wired into
the Makefile — so a fresh clone gets byte-identical tool versions rather than whatever
the distro last shipped. For infrastructure code, the toolchain being reproducible
matters as much as the config being reproducible.

```bash
make deps     # uv sync + ansible-galaxy collection install
```

Collections install to `~/.ansible/collections`, the default user path that every
ansible-core reads — so `ansible-playbook` and `ansible-lint` see the same set.

That last point is the whole reason for this setup. An isolated tool install (`pipx
install ansible-lint`, or equally `uv tool install`) puts the linter in its own venv with
its own `ansible-core`, which cannot see collections that live in the distro's
`site-packages`. Every collection module then reports `unknown-module` and the linter is
quietly blind to most of the repo. Sharing one environment removes the problem rather
than working around it.
