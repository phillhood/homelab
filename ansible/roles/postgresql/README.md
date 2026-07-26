# postgresql

PostgreSQL server confined to a Unix socket, with one owned database. Currently deployed
on CT 102 `forge` (`192.168.1.103`), bundled onto the same container as Forgejo.

## Why the listener is socket-only, permanently

Forgejo is the lab's recovery tool: it exists outside the future Kubernetes cluster
specifically so a broken cluster can be repaired from it. Its database is bundled on
the same container rather than split onto a separate one, because repairing the lab
should require one healthy container, not two. A socket-only listener
(`listen_addresses = ''`, nothing on TCP) also means the store holding the source of
truth has no network attack surface at all — there is nothing to scan, nothing to
brute-force, nothing to firewall. `ss -lnt | grep 5432` returning nothing is the
success condition, not a failure.

This is not specific to Forgejo. Any future service given its own database via this
role should keep the same posture: same-container, socket-only, unless a real
requirement forces otherwise.

## Why the role itself is host-agnostic

`postgresql_db`, `postgresql_user` and `postgresql_password` default to empty strings.
Nothing Forgejo-specific is hardcoded here — the Forgejo database name, role name, and
password live in `group_vars/forge.yaml` / `forge.sops.yaml`, not in this role. When
home services (Mealie, Vikunja, Paperless, ...) arrive later, they get their own
container running this same role with their own `group_vars`, not a shared database
server. Each `hosts:` group that uses this role owns exactly one PostgreSQL instance
and exactly one database.

## `become_user: postgres` needs `become_method: ansible.builtin.su`

The Debian 13 LXC base image (`debian_lxc_base`) has no `sudo` installed — only `su`.
`community.postgresql.postgresql_user`/`postgresql_db` need to run as the `postgres`
system user to authenticate via peer auth over the Unix socket, and Ansible's default
`become_method` is `sudo`. Left at the default, the task fails with `Module result
deserialization failed: No start of json char found` — a red herring; the real error
(`/bin/sh: 1: sudo: not found`) only shows up under `-vvv`, because the failing task
also has `no_log: true` for the password argument.

The actual rule, for the next role that needs `become` on one of these containers:
`become_method: ansible.builtin.su` is always required, because there is no `sudo`
anywhere. `become_flags: "-s /bin/sh"` is *additionally* required only when the target
account's shell is `nologin` — `su` needs to be told what to run the command with in
that case. `ansible/roles/music_share/tasks/syncthing.yaml` needs both, because its
service account has `shell: /usr/sbin/nologin`. `postgres` has `/bin/bash`
(`getent passwd postgres`), so `su` can use it directly and `become_flags` is omitted
here — that is a difference in the account, not a partial or simplified copy of the
`syncthing.yaml` fix.

## The default cluster encoding is `SQL_ASCII`, not `UTF8`

The base LXC image's active locale is `C` (`locale -a` only lists `C`, `C.utf8`,
`POSIX` — no `en_US.UTF-8` or similar). Debian's `pg_createcluster`, run automatically
from the `postgresql-17` package's postinst, picks up the environment's `LANG` at
install time and initializes `template0`/`template1` as `SQL_ASCII` with `C`/`C`
collation accordingly. A plain `CREATE DATABASE ... ENCODING 'UTF8'` against the
default template then fails:

```
new encoding (UTF8) is incompatible with the encoding of the template database (SQL_ASCII)
HINT:  Use the same encoding as in the template database, or use template0 as template.
```

The fix is the module's own documented pattern, not a workaround: `template0` is
guaranteed free of non-ASCII content, so PostgreSQL allows `CREATE DATABASE` to pick a
different encoding when building from it. `tasks/database.yaml` passes
`template: template0` for exactly this reason. The resulting database is
`UTF8`/`C`/`C` (encoding/collate/ctype) — `C` collation is also what Forgejo/Gitea
deployments generally recommend regardless, since locale-aware collation has known
edge cases with case-sensitive username/repo lookups.

This was not chased further into fixing cluster-wide locale generation (e.g. via
`debian_lxc_base`) — that would affect every container built from the base image, is a
bigger decision than this role's scope, and `template0` avoids needing it at all.

## Handler drift after an interrupted run, and why `install.yaml` flushes early

If a play run fails *after* the `listen_addresses` `lineinfile` task has written to
disk but *before* handlers flush at end-of-play, the notified `Restart postgresql`
handler is lost for that run. Because `lineinfile` is idempotent, a subsequent run
sees the file already matches and does not re-notify the handler — so the service can
keep running with a stale, already-superseded config indefinitely, even though
`ansible-playbook` reports clean and `changed=0`. This happened once during this
role's own development, caused by the `sudo`/`become_method` bug above interrupting an
early run; recovery was a manual `systemctl restart postgresql`.

Because the setting guarded by that restart is the socket-only security posture, silent
drift here specifically means "TCP quietly open while Ansible says everything is fine"
— worse than an ordinary stale-config bug. `install.yaml` therefore has an explicit
`ansible.builtin.meta: flush_handlers` immediately after the `listen_addresses` task,
so the restart happens right there instead of waiting for end-of-play. This is not
redundant with the note above, even though it looks like it at a glance: the note
describes the failure this project actually hit; the flush is what closes the window
that caused it, shrinking "notified but not yet restarted" from "the rest of the play"
down to zero tasks. Do not remove the flush because the note above looks like it
already covers this — the note is the incident, the flush is the fix. `make verify`
(added in a later task) is a second, independent check for the same failure mode, not
a replacement for the flush.

## Password handling

`postgresql_password` is passed to `community.postgresql.postgresql_user` and the task
is `no_log: true`, so it never appears in playbook output. It comes from a
`*.sops.yaml` file per host group (e.g. `group_vars/forge.sops.yaml`), generated with
`openssl rand -base64 32 | tr -d '\n/+=' | head -c 32` and encrypted directly via sops
from stdin — the plaintext never touches disk.

## Local socket auth is `scram-sha-256`, not the Debian-default `peer`, for anything but `postgres`

`postgresql-{{ postgresql_version }}`'s postinst writes a `pg_hba.conf` where every
local (Unix-socket) connection authenticates via `peer`: the connecting OS username must
equal the Postgres role name, full stop — no password is ever checked. That is fine for
this role's own `become_user: postgres` tasks (OS user `postgres` connecting as role
`postgres`), but breaks the moment an application connects as its own dedicated role
under a *different* OS account. Forgejo (the first, and so far only, consumer of this
role) is exactly that case: its `app.ini` connects to Postgres role `forgejo` over the
socket, but the OS process runs as `git` (required — the SSH clone URL is
`git@forge.home`, so the service account can't be renamed to match). `peer` auth
rejected that outright with `FATAL: Peer authentication failed for user "forgejo"`,
regardless of the password configured on either side — `peer` doesn't look at it.

`tasks/install.yaml` now rewrites just the catch-all line —
`local   all   all   peer` → `local   all   all   scram-sha-256` — leaving
`local   all   postgres   peer` untouched (matched first, so `become_user: postgres`
keeps working exactly as before). This is what makes the `PASSWD` field in a consuming
role's `app.ini`-equivalent config actually mean something: without this change, no
password-based client can ever authenticate over the socket here, no matter what
password it's configured with. Any future service added to this role inherits the same
fix automatically — it's in the generic `install.yaml`, not scoped to Forgejo.
