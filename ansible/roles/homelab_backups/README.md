# homelab_backups

Pulls config backups for the two things that don't fit the Ansible-configures-the-guest
model: Pi-hole's Teleporter bundle and OPNsense's `config.xml`.

## Bootstrap (one-time, manual)

**OPNsense** — create a scoped `backup` group and user in System → Access, generate an
API key + secret for the user (the "create and download API keys" action on the user
row), then store them in SOPS.

The group needs exactly one privilege, and **it is not the one you would expect**:

| Privilege | ACL key | What it actually covers |
|---|---|---|
| ✅ **Diagnostics: Configuration History** | `page-diagnostics-configurationhistory` | `ui/core/backup/history*`, **`api/core/backup/*`** |
| ❌ System: Configuration: Backups | `page-diagnostics-backup-restore` | `diag_backup.php*` — the legacy web page only |

The privilege *named* after backups grants nothing this role uses. The whole
`/api/core/backup/*` surface is gated behind **Diagnostics: Configuration History**.
Source: OPNsense `src/opnsense/mvc/app/models/OPNsense/Core/ACL/ACL.xml`.

Diagnosing this is awkward because OPNsense returns `403` both for "authenticated but
unprivileged" and — in some cases — for paths you cannot reach. Useful discriminators:

- `401` = bad key/secret
- `302` = no credentials at all
- `404` = route genuinely does not exist
- `403` = valid credentials, privilege denied

So a `403` means the credentials are *fine*. Probe an unrelated endpoint you do have
rights to in order to prove the mechanism works before suspecting the key.

Then:

```bash
sops ansible/inventory/group_vars/opnsense.sops.yaml
```

```yaml
opnsense_api_key: "the-key"
opnsense_api_secret: "the-secret"
```

Same bootstrap-secret pattern as the Terraform token: a human creates it once, SOPS is
the canonical store from then on.

## Run

```bash
ansible-playbook playbooks/backups.yaml              # everything
ansible-playbook playbooks/backups.yaml --tags pihole
ansible-playbook playbooks/backups.yaml --tags opnsense
ansible-playbook playbooks/backups.yaml --tags rotate
```

Writes timestamped backups into `.dev/pihole-backups/`, `.dev/opnsense-backups/`, and
`.dev/music-backups/`. Retention is per *series*, not per directory: `.dev/music-backups/`
holds two independent series written every run (`manifest-*.tsv.gz` and
`config-*.tar.gz`), each pruned to the newest `backup_retention` (default 14) on its own —
so that directory ends up with up to `2 * backup_retention` files, not `backup_retention`.
`rotate.yaml` prunes per `(directory, pattern)` pair, driven by `backup_prune_targets` in
`defaults/main.yaml`, for exactly this reason.

**This role is `changed` on every run by design** — a backup that never changes is
broken. It is the one role where `changed=0` is not the goal.

## Tag slicing needs `apply:`

`backups.yaml` pulls each concern in with `include_role` + `tasks_from`, which bypasses
`tasks/main.yaml` where the tags live. A tag on a *dynamic* include gates only the
include itself, not the tasks it pulls in — so `--tags pihole` would run the include and
then skip everything inside it, reporting a misleading success. Each include therefore
carries both its own tag and `apply: tags: [...]` to push the tag onto the included
tasks.

## Finding the Teleporter archive

`pihole-FTL --teleporter` prints the filename it wrote, so the role reads it from
`stdout` rather than searching `/tmp` by modification age. That is deterministic — no
race window, and no ambiguity if more than one archive is present. The archive is
removed from the Pi-hole host after fetching, so `/tmp` doesn't accumulate.

Export is bare `--teleporter`; **import is `--teleporter <file>`** — there is no
`import` subcommand.

## Forgejo dump

`forgejo dump --skip-package-data` produces one zip holding the database
(`forgejo-db.sql`, dumped straight from the socket-only PostgreSQL instance —
`forgejo dump` reads the connection details, including the `/var/run/postgresql`
socket path, straight out of `app.ini`), the repository tree (`repos/`), and
everything under `APP_DATA_PATH` (`data/`) — avatars, indexers, queues, and the
two files Forgejo self-provisions on first start that live nowhere in SOPS:

- `data/ssh/gitea.rsa` — the SSH host key served on `:2222`. Lose it on a
  rebuild and every client that has ever cloned over SSH gets a
  host-key-changed warning.
- `data/jwt/private.pem` — the OAuth2 RS256 signing key. Lose it and every
  issued token is invalidated.

Confirmed by listing the archive contents (`unzip -l`) rather than trusting the
docs: both files are present, no extra steps needed.

`--skip-package-data` only drops the container registry's blob store — the
images it holds are rebuildable from source, and source is what the rest of
the dump preserves, so excluding them keeps every archive small for no lost
recovery value. An empty `data/tmp/package-upload/` staging directory shows up
in the listing; that is not package data.

`forgejo dump` also embeds the rendered `app.ini`, and there is no
`--skip-config` flag to stop it — `app.ini` is stripped from the archive with
`zip -d` on the forge host itself, before the fetch, so a secret-bearing
archive never crosses the network or lands in `.dev/` even briefly. See
Sensitivity below for why.

The dump runs as `git` (no `sudo` on this host, hence `become_method: su`) and
the `.zip` is fetched to `.dev/forgejo-backups/`, then deleted from the forge
host's `/tmp` immediately after.

## Verifying rotation still works

Retention only prunes once there are more backups than the limit, so it can sit unproven
for weeks. Force it against a low limit and confirm it deletes the oldest:

```bash
ansible-playbook playbooks/backups.yaml --tags rotate -e backup_retention=2
```

## Terraform state

`terraform.tfstate` uses a local backend (`terraform/backend.tf`) and is gitignored, so it
existed in exactly one place on one machine. Losing it does not lose the containers — it
loses the *mapping* between the config and the five live VMIDs, after which
`terraform apply` tries to create CT 100–104 and errors because they already exist.

Each run captures three files:

| File | Purpose |
|---|---|
| `terraform-<ts>.tfstate` | the state itself — the restore path |
| `terraform-<ts>.tfstate.backup` | Terraform's own previous-state file, one apply behind |
| `restore-imports-<ts>.sh` | generated `terraform import` commands, one per container |

The recovery script is **generated from the state at capture time**, not hand-maintained,
so it cannot drift out of step with the container set. It is the fallback for when no
snapshot is usable; restoring the `.tfstate` needs none of it.

This play runs on `localhost` with `connection: local`, because unlike every other series
here the source file is already on the controller.

`make backup-terraform` captures only this series.

## Restore

- **Pi-hole:** import the Teleporter `.zip` — Settings → Teleporter in the web UI, or
  `pihole-FTL --teleporter <file>` on the host. The `pihole` role can also seed a fresh
  install with `-e pihole_teleporter_archive=/abs/path/to/archive.zip`.
- **OPNsense:** System → Configuration → Backups → Restore, upload the `config.xml`.
- **Terraform:** copy the newest `terraform-<ts>.tfstate` to
  `terraform/environments/kvatch/terraform.tfstate`, then `make tf-plan` — `No changes`
  confirms it matches reality. If no snapshot is usable, run the matching
  `restore-imports-<ts>.sh` from `terraform/environments/kvatch` instead, which rebuilds
  the mapping by importing each existing container.

## Sensitivity

`config.xml` contains secrets in cleartext. It stays in gitignored `.dev/` and is never
committed. If it ever needs to go offsite, `age`-encrypt it first.

**The Terraform state carries no secret, and that was measured rather than assumed.** All
five `initialization.password` fields are empty strings — the module provisions containers
with SSH keys only, and `ssh_public_keys` are public by definition. So the state passes the
rule below trivially: it duplicates nothing sops manages, and it is irreplaceable. It is
still written `0600`, defensively.

That status is **contingent on staying key-only**. The moment anyone sets a root password
in `terraform/modules/proxmox-lxc`, `terraform.tfstate` starts carrying it in cleartext,
`backup_retention` multiplies it by 14, and this series needs the same treatment as
`config.xml`. Re-check with `python3 -c` over the state rather than grepping for the key
name — the field is always *present*, which is what makes a grep misleading.

The music config archive (`.dev/music-backups/config-*.tar.gz`) does contain secrets, and
the rule governing it is narrower than "no credentials in backups".

**The rule is: never duplicate a sops-managed secret in cleartext.** The archive holds
Syncthing's identity and config, not just its config: `config.xml` carries its own
credentials — a bcrypt GUI password hash and a plaintext REST `<apikey>` — and `key.pem`
(with `cert.pem`) is the device's private key, the thing that makes its device ID
(`Q6WY5F5-…`) reproducible. All three are kept anyway, because that state is irreplaceable
and exists nowhere else — restoring `config.xml` onto a rebuilt container without `key.pem`
generates a new keypair and a new device ID, and every paired client rejects it until it is
re-paired by hand. It is the same trade already accepted for OPNsense's `config.xml` above.
The rendered `docker-compose.yml` is excluded because it fails the rule twice over: it is
byte-for-byte regenerable from `music_stack/templates/docker-compose.yml.j2` plus vars
already sops-encrypted in git, so archiving it recovers nothing, and doing so would put
the slskd credentials on disk in the clear beside the encrypted copies — undoing the
`no_log: true` the deploy task applies for exactly that reason. Retention multiplies the
exposure by `backup_retention`.

`smb.conf` is also derived, and is kept for a reason that is not "it is harmless": it is
the file Samba actually runs, deployed behind `validate: testparm -s %s`, so a snapshot
captures drift a static Jinja template cannot show you. Keep that bar for anything added
later — irreplaceable state, or drift visibility on a live config. Derived-and-inert
files do not earn a place, and derived files carrying a sops-managed secret are excluded
outright.

Forgejo's `app.ini` fails the same rule, embedded in the dump by `forgejo dump` itself
with no flag to stop it. It is byte-for-byte regenerable from
`forgejo/templates/app.ini.j2` plus five vars already sops-encrypted in
`group_vars/forge.sops.yaml`, so archiving it recovers nothing. It also carries `PASSWD`,
`SECRET_KEY`, `INTERNAL_TOKEN`, `JWT_SECRET`, and `LFS_JWT_SECRET` in cleartext — undoing
the `no_log: true` the `Render app.ini` task in `forgejo/tasks/config.yaml` applies for
exactly this reason — and `backup_retention` multiplies that exposure by 14. It is
stripped from the archive with `zip -d` on the forge host before the fetch, so it never
reaches `.dev/`.

**Restoring Forgejo does not extract `app.ini` from the zip — there is none.** It is
regenerated by rerunning the `forgejo` role (`ansible-playbook playbooks/site.yaml --tags
forgejo` or `--limit forge`), which re-renders it from the template and the same
sops-encrypted vars. That is expected, not a defect in the backup: a restore that finds
`app.ini` missing from the archive should reach for Ansible, not conclude the dump is
broken. `data/ssh/gitea.rsa` and `data/jwt/private.pem`, by contrast, are irreplaceable —
Forgejo self-provisions them once and there is no template to re-render them from — which
is exactly why they are kept in the dump (see Forgejo dump above) while `app.ini` is not.
