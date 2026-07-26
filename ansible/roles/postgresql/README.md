# postgresql

PostgreSQL confined to a Unix socket, with one owned database. Host-agnostic — nothing
Forgejo-specific is hardcoded. Currently on CT 102 `forge`, bundled with Forgejo.

## Usage

| Tag | Does |
|---|---|
| `install` | package, `listen_addresses`, `pg_hba.conf`, enable + start |
| `database` | creates the role and the database |
| `postgresql` | both |

Each `hosts:` group using this role owns exactly one instance and exactly one database.
When home services arrive later they get their own container running this same role with
their own `group_vars` — not a shared database server.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `postgresql_version` | `17` | |
| `postgresql_db` | `""` | empty is valid — the role is host-agnostic |
| `postgresql_user` | `""` | |
| `postgresql_password` | `""` | from a `*.sops.yaml`; unread under `peer` |
| `postgresql_listen_addresses` | `""` | empty means socket-only. **Load-bearing** |

## Invariants

- **`listen_addresses = ''` is the security posture, not an unset value.** Nothing listens
  on TCP, so the store holding the source of truth has no network attack surface at all —
  nothing to scan, brute-force or firewall. `ss -lnt | grep 5432` returning nothing is the
  success condition. Any future service given a database by this role should keep the same
  posture: same-container, socket-only, unless a real requirement forces otherwise.
- **Do not remove the `flush_handlers` after the `listen_addresses` task.** Without it, a
  run that fails between writing that file and end-of-play loses the notified restart — and
  because `lineinfile` is idempotent, the next run sees the file already correct and does
  not re-notify. The service then keeps the superseded config indefinitely while Ansible
  reports clean. For this setting that means "TCP quietly open while everything looks fine".
- **`peer` is the default for every local connection and stays that way.** It is the
  stronger primitive — a kernel-verified UID, not a shared secret that can leak or be
  brute-forced. Password auth is opt-in per database: one targeted `pg_hba.conf` line ahead
  of the generic `local all all peer`, added only when `postgresql_db` and `postgresql_user`
  are both set. `postgresql_password` defaulting to `""` is safe precisely because `peer`
  never reads it.
- **`template: template0` is required, not stylistic.** The base image's locale is `C`, so
  `pg_createcluster` initialises `template1` as `SQL_ASCII`, and
  `CREATE DATABASE … ENCODING 'UTF8'` against it fails outright. `template0` is guaranteed
  free of non-ASCII content, so PostgreSQL allows a different encoding when building from it.
- **`become_method: ansible.builtin.su` is required** — the Debian 13 LXC base has no
  `sudo`. Left at the default the task fails with `Module result deserialization failed`,
  which is a red herring; the real error only appears under `-vvv`, because the failing task
  is also `no_log`. `become_flags: "-s /bin/sh"` is *additionally* needed only when the
  target account's shell is `nologin`, which `postgres` is not.

The one consumer needing the password-auth escape hatch is Forgejo, whose OS account
(`git`) cannot match its Postgres role name (`forgejo`). See `../forgejo/README.md`.

Rationale and the incidents behind these are in the local notes for this role.
