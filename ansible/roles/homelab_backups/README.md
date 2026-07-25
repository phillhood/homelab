# homelab_backups

Pulls config backups for the two things that don't fit the Ansible-configures-the-guest
model: Pi-hole's Teleporter bundle and OPNsense's `config.xml`.

## Bootstrap (one-time, manual)

**OPNsense** — create a scoped `backup` group and user in System → Access, grant it only
the backup/config privileges, generate an API key + secret for the user, then:

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

Writes timestamped backups into `.dev/pihole-backups/` and `.dev/opnsense-backups/`,
then keeps the newest `backup_retention` (default 14) in each.

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

## Verifying rotation still works

Retention only prunes once there are more backups than the limit, so it can sit unproven
for weeks. Force it against a low limit and confirm it deletes the oldest:

```bash
ansible-playbook playbooks/backups.yaml --tags rotate -e backup_retention=2
```

## Restore

- **Pi-hole:** import the Teleporter `.zip` — Settings → Teleporter in the web UI, or
  `pihole-FTL --teleporter <file>` on the host. The `pihole` role can also seed a fresh
  install with `-e pihole_teleporter_archive=/abs/path/to/archive.zip`.
- **OPNsense:** System → Configuration → Backups → Restore, upload the `config.xml`.

## Sensitivity

`config.xml` contains secrets in cleartext. It stays in gitignored `.dev/` and is never
committed. If it ever needs to go offsite, `age`-encrypt it first.
