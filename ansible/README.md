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

## Toolchain

`ansible-core`, `ansible-lint` and `jmespath` are pinned in the repo-root
`pyproject.toml` and locked in `uv.lock`; the collections in `requirements.yaml`.
Everything runs through `uv run`, wired into the Makefile.

```bash
make deps     # uv sync + ansible-galaxy collection install
```

Collections install to `~/.ansible/collections`, the default user path every ansible-core
reads, so `ansible-playbook` and `ansible-lint` see the same set. Do not install the linter
into its own venv — it then cannot see these collections and goes quietly blind to most of
the repo.
