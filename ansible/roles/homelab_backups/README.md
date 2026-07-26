# homelab_backups

Pulls the backup series for everything the Ansible-configures-the-guest model does not
reproduce: Pi-hole's Teleporter bundle, OPNsense's `config.xml`, the music manifest and
service config, the Forgejo dump, and the Terraform state. The music *content* backup is
the one exception — it runs a script that `music_storage` installs on `kvatch` rather than
pulling anything to the controller.

## Usage

```bash
make backup                  # every series
make backup-pihole           # --tags pihole         Teleporter archive
make backup-opnsense         # --tags opnsense       config.xml
make backup-music            # --tags music          manifest + service config
make backup-music-content    # --tags music-content  the files themselves, via restic
make backup-forgejo          # --tags forgejo        forgejo dump
make backup-terraform        # --tags terraform      tfstate + recovery script
                             # --tags rotate         prune, runs last
```

Everything lands under `{{ repo_root }}/.dev/` — `pihole-backups/`, `opnsense-backups/`,
`music-backups/`, `forgejo-backups/`, `terraform-backups/` — except `music-content`, which
goes to a restic repository on `kvatch` and keeps its own retention.

The two music series do different jobs. `--tags music` writes a manifest of path, size and
mtime plus the service config archive: it tells you what you had, and holds no audio.
`--tags music-content` holds the files, by shelling out to `/usr/local/sbin/music-backup`.
This role asserts that script exists and runs it rather than reimplementing the restic
calls, so the daily timer and the on-demand run are the same code.

## Bootstrap (one-time, manual)

**OPNsense** — create a scoped `backup` group and user in System → Access, generate an API
key + secret on the user row, then `sops ansible/inventory/group_vars/opnsense.sops.yaml`
and set `opnsense_api_key` / `opnsense_api_secret`. Same pattern as the Terraform token: a
human creates it once, SOPS is canonical from then on.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `backup_retention` | `14` | per series, not per directory |
| `backup_prune_targets` | see `defaults/` | `(directory, pattern)` pairs `rotate.yaml` walks |
| `opnsense_host` | `192.168.1.1` | |
| `backup_*_dir` | `{{ repo_root }}/.dev/…` | one per series |

**Requires** `opnsense_api_key` and `opnsense_api_secret` from `opnsense.sops.yaml`, and
`music_backup_script` from `group_vars/proxmox.yaml`.

## Restore

- **Pi-hole** — import the Teleporter `.zip`: Settings → Teleporter in the web UI, or
  `pihole-FTL --teleporter <file>` on the host. The `pihole` role can seed a fresh install
  with `-e pihole_teleporter_archive=/abs/path/to/archive.zip`.
- **OPNsense** — System → Configuration → Backups → Restore, upload the `config.xml`.
- **Music content** — `make music-restore DEST=/var/tmp/restore-test` pulls the newest
  snapshot on `kvatch`; add `SNAPSHOT=<id>` for an older one. Restore somewhere scratch and
  compare before writing over `/mnt/music`. `make music-snapshots` lists what is available.
- **Forgejo** — extract the dump, then rerun the role to regenerate `app.ini`
  (`--tags forgejo`). It is deliberately not in the archive; see the invariants.
- **Terraform** — copy the newest `terraform-<ts>.tfstate` over
  `terraform/environments/kvatch/terraform.tfstate`, then `make tf-plan`; `No changes`
  confirms it matches reality. If no state is usable, run the matching
  `restore-imports-<ts>.sh` from that directory instead, which rebuilds the mapping by
  importing each existing container.

## Invariants

**The rule for what goes in a backup: never duplicate a sops-managed secret in
cleartext.** Irreplaceable state earns a place even when it carries credentials — Syncthing's
`key.pem` and OPNsense's `config.xml` both do. Derived-and-inert files do not. Derived files
carrying a sops-managed secret are excluded outright, because archiving them recovers
nothing and `backup_retention` multiplies the exposure by 14.

- **`app.ini` is stripped from the Forgejo dump with `zip -d` on the forge host, before the
  fetch.** `forgejo dump` embeds it and offers no flag to stop it. It carries five secrets
  that are already in sops, and it is regenerable from the template — so a restore that
  finds it missing should reach for Ansible, not conclude the dump is broken.
- **Push mirrors must use SSH, never HTTPS.** An HTTPS mirror writes
  `url = https://<user>:<token>@github.com/...` into the repo's own git config at `0644`,
  and `repos/` is in the dump — measured, a live PAT in cleartext. Forgejo sanitises it for
  *display*, so the UI looks clean while the on-disk copy is not. Re-check after any mirror
  change: `grep -rlE "https://[^@/[:space:]]+@github\.com" <extracted archive>` must find
  nothing.
- **OPNsense's backup API is gated behind `Diagnostics: Configuration History`**, not the
  privilege named after backups — `System: Configuration: Backups` covers only the legacy
  `diag_backup.php` page and grants nothing this role uses.
- **Every include in `backups.yaml` needs `apply: tags:` as well as its own tag.** A tag on
  a dynamic include gates the include only, not the tasks it pulls in, so `--tags pihole`
  would run the include, skip everything inside, and report success.
- **This role is `changed` on every run by design.** A backup that never changes is broken;
  it is the one role where `changed=0` is not the goal.
- Retention prunes per `(directory, pattern)` pair, so `.dev/music-backups/` holds up to
  `2 * backup_retention` files across its two series. `music-content` is deliberately
  absent from `backup_prune_targets` — restic does its own.
- Teleporter export is bare `--teleporter`; import is `--teleporter <file>`. There is no
  `import` subcommand, and a stray word there is read as the filename.
- The Terraform state carries no secret **only while the module stays key-only**. Setting a
  root password in `terraform/modules/proxmox-lxc` puts it in the state in cleartext, and
  this series then needs the same handling as `config.xml`. Re-check by parsing the state,
  not grepping — the field is always present, which is what makes a grep misleading.

Rotation sits unproven until there are more backups than the limit. Force it:

```bash
ansible-playbook playbooks/backups.yaml --tags rotate -e backup_retention=2
```

Rationale, measurements and the per-file sensitivity analysis:
`.dev/docs/ansible/homelab_backups.md`.
