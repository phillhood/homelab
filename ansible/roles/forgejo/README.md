# forgejo

Forgejo git service on CT 102 `forge` (`192.168.1.103`), behind Caddy at
`git.lab.shychedelic.com`, with its own built-in SSH server on `:2222` and its own
Postgres database (via the `postgresql` role, socket-only, same container).

## `ROOT_URL` is single-valued and must never change after the first push

`ROOT_URL` (`https://git.lab.shychedelic.com/`, from `group_vars/forge.yaml`) is not
just a display string. Forgejo bakes it into every clone URL it hands back over the
API and web UI, into webhook payload URLs, and — critically for this build — into the
fully-qualified image reference a `docker push`/`docker pull` uses against Forgejo's
built-in OCI package registry (`git.lab.shychedelic.com/shychedelic/<image>:<tag>`).
Once an image has been pushed under a given `ROOT_URL`, that hostname is part of the
image's identity as far as any client that pulled it is concerned. Changing `ROOT_URL`
later (a domain rename, moving the container, switching `lab_domain`) does not migrate
existing references — it orphans them. Treat `forgejo_root_url` as a one-way door: pick
it once, verify it (Step 11's certificate/HTTP checks), and only change it as part of a
deliberate, coordinated migration, never as a routine config edit.

## SSH is Forgejo's own built-in server on `:2222`, not proxied through Caddy

`START_SSH_SERVER = true` / `SSH_LISTEN_PORT = 2222` in `app.ini` makes Forgejo run its
own SSH daemon in-process, independent of the host's OpenSSH (which stays on the usual
port 22 for `root@` administration). This is not proxied through Caddy at all — Caddy
is an HTTP/HTTPS(/HTTP-3) reverse proxy; routing arbitrary TCP (raw SSH) through it
needs the `layer4` app/plugin, which is not part of the `proxy` role's Caddy build in
this repo. Clients connect straight to `forge1:2222` (`ssh://git@forge.home:2222/...`),
bypassing Caddy and CT 104 entirely. This also means the SSH path has no TLS
certificate to inspect or renew — it's plain SSH host-key trust, confirmed once per
client the ordinary way (`ssh-keyscan` / accept-on-first-connect).

## Two more secrets than the original plan accounted for

`forge.sops.yaml` ends up holding **six** application keys (`postgresql_password`,
`forgejo_secret_key`, `forgejo_internal_token`, `forgejo_admin_password`,
`forgejo_jwt_secret`, `forgejo_lfs_jwt_secret`) plus `sops.mac` — `make secrets` reports
`encrypted (7)`, not the `(5)` the task plan expected. The two extra keys were not
optional additions; without them the service will not start at all.

`forgejo generate secret` (the CLI both `forgejo_secret_key` and
`forgejo_internal_token` are seeded from) lists exactly three secret types it knows how
to generate: `SECRET_KEY`, `INTERNAL_TOKEN`, and `JWT_SECRET` (alias
`LFS_JWT_SECRET`). The original plan pre-generated the first two and let Forgejo
auto-generate the third at first boot — which is how Gitea/Forgejo behaves when
`[oauth2] JWT_SECRET` (used to sign OAuth2/device-flow tokens) or `[server]
LFS_JWT_SECRET` (used to sign Git LFS transfer tokens, needed because
`LFS_START_SERVER = true`) are absent: it generates a value in memory and then tries to
**write it back into `app.ini`** so the next restart is consistent. That write fails
under this role's file ownership (`app.ini` is `root:{{ forgejo_user }}`, mode `0640` —
deliberately not writable by the `git` user that the service runs as, so a compromised
Forgejo process can't rewrite its own security config) and Forgejo treats that as fatal,
crash-looping forever with:

```
[F] save oauth2.JWT_SECRET failed: failed to save "/etc/forgejo/app.ini": open /etc/forgejo/app.ini: permission denied
[F] Unable to load settings from config: lfs key initialization failed: [server] save server.LFS_JWT_SECRET failed: ...
```

Loosening `app.ini`'s permissions so Forgejo could self-heal was considered and
rejected — it defeats the point of the restrictive mode for a file that also holds the
database password and both other secrets. The fix instead follows the same pattern
already used for `SECRET_KEY`/`INTERNAL_TOKEN`: pre-generate both values with
`forgejo generate secret JWT_SECRET` (once for `[oauth2] JWT_SECRET`, once more for
`[server] LFS_JWT_SECRET` — they are two independent values even though the generator
subcommand is the same one), store them in `forge.sops.yaml` as `forgejo_jwt_secret` /
`forgejo_lfs_jwt_secret`, and template them into `app.ini` so Forgejo never has a reason
to write to its own config file after install.

## Why Forgejo is the one consumer that needs the `postgresql` role's password-auth escape hatch

The `postgresql` role defaults every local (Unix-socket) connection to `peer` auth —
see that role's README for why `peer` is the stronger primitive and stays the default
everywhere except where it's structurally impossible to use. Forgejo is that exception.
`peer` requires the connecting OS username to equal the Postgres role name; Forgejo's
`app.ini` connects to the socket as Postgres role `forgejo`, but the OS process runs as
`forgejo_user` (`git`), and that can't be changed to match — the SSH clone URL is
`ssh://git@forge.home:2222/...`, so `git` is load-bearing as the OS/service account
name, not an arbitrary choice. `git != forgejo`, so `peer` rejected the connection
outright with `FATAL: Peer authentication failed for user "forgejo"`, regardless of
whether `PASSWD` in `app.ini` was correct — `peer` never looks at it.

The `app.ini` template in this role includes a `PASSWD` field for exactly the reason
that field exists on every other Postgres client config: it assumes password auth over
the socket. The `postgresql` role now adds one line to `pg_hba.conf`, specific to the
`forgejo`/`forgejo` database/role pair, ahead of the unchanged `local all all peer`
catch-all (see `ansible/roles/postgresql/tasks/install.yaml` and that role's README) —
narrow enough that no other consumer of that role, present or future, loses `peer` by
default.

## The admin-account idempotency guard

`tasks/admin.yaml` creates the admin user only `when: forgejo_admin_user not in
forgejo_users.stdout`. `forgejo admin user list` prints a table with one row per user,
username included as a bare column value, so a simple substring test against `stdout`
is sufficient here (`forgejo_admin_user` is a single specific username, not a prefix of
anything else in this deployment) — verified by running `make idempotent
LIMIT=forge1,proxy1` after the admin account exists: the second converge reports
`changed=0` for `forgejo : Create the admin account`, which would fail loudly (`when:`
always true) if the guard were wrong.

## `become_method: ansible.builtin.su`

Same reason as the `postgresql` role: the Debian 13 LXC base image has no `sudo`, only
`su`. `tasks/admin.yaml` runs `forgejo admin user ...` as `become_user:
"{{ forgejo_user }}"` (`git`), which has a real login shell (`/bin/bash`), so unlike
`music_share`'s `nologin` service accounts, `become_flags` is not needed here.

## `GITEA_WORK_DIR` has to be set for CLI invocations too, not just the systemd unit

`forgejo admin user list`/`create` need `GITEA_WORK_DIR` in their environment the same
way the systemd unit does (`forgejo.service.j2` already sets it) — without it, the CLI
does not reliably find `app.ini`'s companion runtime state under `forgejo_home`.
`tasks/admin.yaml` sets `environment: { GITEA_WORK_DIR: "{{ forgejo_home }}" }` on both
tasks for this reason.

## A version bump can reintroduce the `app.ini` crash-loop

The `JWT_SECRET`/`LFS_JWT_SECRET` issue above is not a one-time quirk of v16.0.1 — it's
what Forgejo does *in general* when it wants to persist a generated value into a config
key that isn't set yet, and `app.ini` is deliberately not writable by the service
account. A future release can introduce another self-provisioned key the same way
without warning (changelogs don't reliably call this out). Before bumping
`forgejo_version`, check whether the new release adds any newly auto-generated
`app.ini` keys, and if so pre-generate and template them the same way as the four
secrets here — don't find out via a crash-loop on the next converge. This matters more
on this host than it would elsewhere: `forge1` is the lab's recovery tool, so a broken
converge here isn't just "one service down," it's "the tool meant to fix everything
else is itself down."

## `forgejo admin user create --password` puts the admin password on the target's process table

`tasks/admin.yaml`'s "Create the admin account" task passes `--password
{{ forgejo_admin_password }}` as a CLI argument. Ansible's `no_log: true` on that task
keeps the value out of playbook output, logs, and `-v` verbosity — but it does nothing
about the OS itself: for the brief moment the `forgejo admin user create` process runs
under `become_user: git`, the plaintext password is visible to anything reading
`/proc/<pid>/cmdline` on `forge1` (e.g. `ps aux` run by another process on that host
during that window). This is inherent to Forgejo's CLI, which has no
`--password-stdin`/`--password-file` equivalent for this subcommand as of v16.0.1 —
there is no workaround available inside this role, only awareness. It's a narrow
window (one `admin.yaml` run, first install only, guarded by the same idempotency check
that skips this task on every subsequent converge — see below), but it's real, and
worth knowing if `forge1` is ever shared with a less-trusted process.

## GitHub push mirrors are per-repository UI config, not Ansible's job

Mirroring a repository out to GitHub (`Settings -> Repository -> Push Mirror` in the
Forgejo UI) is configured by hand, one repository at a time, by design — it is not
templated or driven from `group_vars` here. The GitHub PAT a mirror needs lives
inside Forgejo's own database (encrypted with the instance's `SECRET_KEY`, the same
mechanism Forgejo uses for its other stored remote credentials), **not** in
`forge.sops.yaml` or any other SOPS file — this role has no variable for it and
never will, short of a future task that decides to automate mirror creation via the
API. See the top-level roadmap for the current manual status.

## Backups exclude package data on purpose

`homelab_backups`' Forgejo dump task runs `forgejo dump --skip-package-data`. The
container registry blob store under `APP_DATA_PATH` is the only thing that flag
drops — those images (including museek's own, once it ships) are rebuildable from
source in their own repositories, so the dump doesn't need to preserve the built
artifacts to make a restore whole. Everything irreplaceable (the database, the git
trees, the self-provisioned SSH host key and JWT signing key) is still captured; see
`homelab_backups/README.md`'s "Forgejo dump" section for the full inventory of
what's in and out of the archive, including why `app.ini` itself is deliberately
absent.

## Verifying `git.{{ lab_domain }}` before the vhost existed

Before this role landed, `https://git.lab.shychedelic.com/api/healthz` returned `200`
with body `tier0 proxy ok` — the `proxy` role's catch-all `handle {}` block in the
Caddyfile, not a real Forgejo response. `200` alone is not evidence of anything; the
body has to be checked. After this role, the same URL returns Forgejo's real health
payload (`{"status":"pass", ...}`), and the catch-all block only ever serves domains
with no more specific `handle` block ahead of it in the Caddyfile — `@git` now sits
before `@registry`, per Step 8.
