# forgejo

Forgejo git service on CT 102 `forge` (`192.168.1.103`), behind Caddy at
`git.lab.shychedelic.com`, with its own built-in SSH server on `:2222` and its own Postgres
database via the `postgresql` role — socket-only, same container.

## Usage

| Tag | Does |
|---|---|
| `install` | git + git-lfs, the `git` user, directories, the binary, the systemd unit |
| `config` | renders `app.ini`, starts the service, waits for `/api/healthz` |
| `admin` | creates the admin account if it does not exist |
| `forgejo` | all three |

SSH clones go straight to `forge1:2222` (`ssh://git@forge.home:2222/...`), not through
Caddy — Caddy is an HTTP proxy, and routing raw TCP would need the `layer4` plugin, which is
not in this build. So the SSH path has no certificate to inspect or renew; it is plain
host-key trust.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `forgejo_version`, `forgejo_sha256` | `group_vars/forge.yaml` | bump together |
| `forgejo_root_url` | — | **required**, one-way door, see invariants |
| `forgejo_admin_user`, `forgejo_admin_email` | — | **required** |
| `forgejo_user` | `git` | load-bearing — it is the SSH clone username |
| `forgejo_home` | `/var/lib/forgejo` | |
| `forgejo_config_dir` | `/etc/forgejo` | |
| `forgejo_http_port`, `forgejo_ssh_port` | `3000`, `2222` | |

**Requires** six secrets from `forge.sops.yaml`: `postgresql_password`,
`forgejo_secret_key`, `forgejo_internal_token`, `forgejo_admin_password`,
`forgejo_jwt_secret`, `forgejo_lfs_jwt_secret`. `make secrets` reports `encrypted (7)` —
those six plus `sops.mac`.

## Invariants

- **`forgejo_root_url` is a one-way door.** Forgejo bakes it into every clone URL it hands
  back and into the fully-qualified image reference for its OCI registry
  (`git.lab.shychedelic.com/shychedelic/<image>:<tag>`). Once an image has been pushed under
  a given `ROOT_URL`, that hostname is part of its identity for every client that pulled it.
  Changing it later does not migrate references, it orphans them. Only change it as a
  deliberate, coordinated migration — never as a routine config edit.
- **Pre-generate every secret Forgejo would otherwise self-provision, and check for new ones
  before bumping `forgejo_version`.** `app.ini` is `root:git` mode `0640`, deliberately not
  writable by the service account. When Forgejo wants to persist a generated value into a
  config key that is not set, that write fails and it treats the failure as fatal —
  crash-looping forever. This is what it does *in general*, not a quirk of one release, and
  changelogs do not reliably call it out. `JWT_SECRET` and `LFS_JWT_SECRET` were both found
  this way, after the fact.
- **Do not loosen `app.ini`'s permissions to let Forgejo self-heal.** That file also holds
  the database password and the other secrets; the restrictive mode is the point.
  Pre-generate instead.
- **`become_method: ansible.builtin.su` is required** — the Debian 13 LXC base ships no
  `sudo`. `become_flags` is not needed here, because `git` has a real login shell, unlike
  `music_share`'s `nologin` service accounts.
- **`GITEA_WORK_DIR` must be set for CLI invocations too**, not just in the systemd unit, or
  `forgejo admin user ...` does not reliably find `app.ini`'s companion runtime state.
- **A `200` from `git.lab.shychedelic.com` is not evidence Forgejo is up.** The `proxy`
  role's catch-all `handle {}` returns `200` with body `tier0 proxy ok` for any subdomain
  with no more specific block. Check the body, not the status.
- `HTTP_ADDR = 0.0.0.0` serves cleartext HTTP to the whole LAN on `:3000`, not only to
  Caddy, because Caddy runs on a different container. Forgejo's own auth still applies; what
  is missing is transport confidentiality and any restriction on who may connect. See the
  backlog's "no host firewall on Tier 0".
- `forgejo admin user create --password` puts the password on the target's process table for
  the life of that one process. `no_log` hides it from Ansible, not from `/proc`. Inherent
  to Forgejo's CLI — there is no `--password-stdin` equivalent — and it runs on first
  install only.

GitHub push mirrors are configured per repository in Forgejo's web UI, by hand, on purpose.
The PAT lives in Forgejo's own database encrypted with `SECRET_KEY`, never in SOPS. **They
must use SSH, not HTTPS** — see `homelab_backups/README.md` for why an HTTPS mirror puts a
live token into the backup archive.

Rationale, the crash-loop diagnosis and why this is the one consumer needing Postgres
password auth: `.dev/docs/ansible/forgejo.md`.
