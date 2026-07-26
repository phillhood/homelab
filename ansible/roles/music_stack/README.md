# music_stack

Docker Engine plus the slskd compose stack in CT 101.

## Docker in an unprivileged LXC

Needs `nesting=1` and `keyctl=1`, set by `music_storage/tasks/container_mount.yaml` via
`pct set`. This container is the deliberate exception to the "no nesting" baseline in
`debian_lxc_base` — see that role's README.

Installation succeeding proves nothing. The real test is:

```bash
ssh root@192.168.1.102 'docker run --rm hello-world'
```

If that hangs or errors on cgroups or the keyring, a feature flag is missing or the
container has not been rebooted since it was set.

## The Docker signing key is fetched with force: true

`get_url` skips the download whenever the destination file already exists, comparing
nothing about its content. Without `force: true`, an upstream rotation of Docker's
signing key would leave the stale copy in place at `/etc/apt/keyrings/docker.asc`
indefinitely, and `apt` would start failing signature verification on the docker-ce
repository with no automated recovery — the file exists, so the task would keep
reporting success while apt broke. `force: true` re-fetches the key on every run
regardless of whether the destination exists, but still only reports `changed` when the
fetched content actually differs, so idempotent runs stay `changed=0`.

## The image store stays off the SSD

`/var/lib/docker` lives on the container root disk. Keeping it there makes the container
disposable and the media disk pure data. Verify with:

```bash
ssh root@192.168.1.102 'findmnt -no TARGET -T /var/lib/docker'   # expect /
```

## slskd sees the library read-only

`{{ music_container_mount }}/library:/library:ro` — slskd shares the library back to
Soulseek without ever being able to modify it. This is a load-bearing `:ro`:

```bash
ssh root@192.168.1.102 'docker exec slskd touch /library/x'   # must fail, read-only
```

Two promotion paths coexist. Anything grabbed by hand through slskd's web UI lands in
`downloads/complete/` and is promoted manually over SMB. museek, once deployed, writes
tagged files straight into `library/` — it has no mode that skips tagging, so
`MUSEEK_MATCH_THRESHOLD` is the real quality gate rather than a human.

## slskd's incomplete directory is deliberately not mounted

slskd does not auto-create non-default directories. Pointing its incomplete dir at a
freshly created shared mount can leave it unable to start, after which museek blocks
forever on `depends_on: service_healthy`. Incomplete downloads therefore stay on slskd's
own `/app` volume, which it creates itself. `/srv/music/downloads/incomplete/` exists on
the SSD but is intentionally unused.

## SLSKD_UMASK is an image convention, not a slskd setting

`slskd --help` has no umask option and slskd's own config exposes only
`transfers.download.destination.permissions.mode`. Both are red herrings — the mechanism
is the image's `/entrypoint.sh`, which runs `umask "$SLSKD_UMASK"` before exec'ing. The
image bakes in `0022`; the override to `0002` keeps downloads group-writable.

**Two obvious ways to check this give the wrong answer.** `docker inspect -f
'{{.State.Pid}}'` returns `tini`, which forks the entrypoint rather than becoming it, and
`docker exec` never goes through the entrypoint at all — both report `0022` against a
setting that is working. Use `.dev/scripts/verify-slskd-umask.sh`, which reads the real
slskd pid from `docker top`.

## The custom app is museek, and it is wired but deliberately not deployed

`music_app_image` maps to museek's `MUSEEK_IMAGE` and `music_discord_image` maps to the
discord bot's image; both default to `""` and the compose template omits the matching
service entirely when its variable is empty. **Both are currently set to `""` in
`inventory/group_vars/music.yaml`, on purpose** — this is not an unfinished state, it is
the gate doing exactly what it was built for. The full env surface is already written and
ready to go the moment the image variable is set — `MUSEEK_SLSKD_URL`, the shared API key,
`MUSEEK_DEST_PATH`, `MUSEEK_UMASK`, Spotify and MusicBrainz config, and a
`/srv/music/.state/museek` bind mount for its SQLite store — along with the sops secrets
(`museek_discord_token`, `museek_discord_guild_id`) and `museek_musicbrainz_contact`.

The images pull anonymously from the self-hosted registry once `music_app_image` and
`music_discord_image` are set. That was tried once, and museek-discord came up cleanly and
logged into Discord — it carries no `user:` override, so it runs as its image's own
default user — but museek itself does not start:
`git.lab.shychedelic.com/shychedelic/museek:0.1.0` crash-loops under
`user: "1500:1500"` with `PermissionError: [Errno 13] Permission denied: '.env'`. Its
`Config` (`pydantic_settings`) hardcodes `env_file=".env"`, a relative path resolved
against the container's `WORKDIR` (`/home/appuser`), which the image bakes as
`drwx------` owned by uid 10001 — uid 1500 cannot even `stat` inside that directory, so
the process dies before it ever binds its HTTP listener and `/healthz` never comes up.
This is an image defect, not a compose or permission-model problem on this side, and it
is being fixed upstream (a writable/owned `WORKDIR`, or dropping the implicit `env_file`
lookup) and will ship as `0.1.1`. Deploying it here again is then a one-line change —
set `music_app_image` (and `music_discord_image`) back to their registry tags and
converge — not a rebuild of any of the wiring described above. `museek-discord` declares
`networks: [music]`, matching `slskd` and `museek` exactly, so it can reach museek by
service name (`http://museek:8080`) rather than landing on compose's `default` network.

**Bind mounts are mandatory, never named volumes**, for whenever it is redeployed — a
named volume initialises from the museek image's uid 10001 and becomes unwritable under
the `user: "1500:1500"` override.

## One API key, two names

`museek_slskd_api_key` renders as both museek's `MUSEEK_SLSKD_API_KEY` and slskd's own
`SLSKD_API_KEY`, so they are equal by construction. Never configure a second key.

## Troubleshooting a failed bring-up

Both compose invocations carry `no_log: true`, because the rendered file holds three
secrets and a YAML parse error typically echoes the offending line. You lose the
diagnostic body, not the failure itself. To see what actually went wrong, run it by hand:

```bash
ssh root@192.168.1.102 'cd /opt/music-stack && docker compose up -d'
```

## Placeholder credentials are refused, and this is not theoretical

`compose.yaml` asserts the Soulseek credentials are not `FILL_ME` before deploying.
Soulseek has no separate registration step — the first login with an unused name *claims*
it. Deploying with placeholders once registered a live public account named `FILL_ME` on
the real network from this house's IP. It shared nothing and was stopped, but the name
stays claimed.

## Port 2235 needs a manual OPNsense forward

Everything else is LAN-only. `2235/tcp` is the Soulseek listen port and is the only
external change in this design. Without the forward, slskd falls back to indirect
connections and download reliability drops noticeably.

Add it in **Firewall → NAT → Port Forward**: WAN, TCP, destination port `2235`,
redirect target `192.168.1.102:2235`. Not automated — related to the OPNsense API work
in the backups role.

## k8s trajectory

Storage and the share stay put; slskd and the app are the migration candidates. They are
already images — Deployment + Service + NodePort, config in a ConfigMap, secrets via
SOPS. `csi-driver-smb` lets a pod mount the same Samba share as a PV, so migration is
"write manifests, point the PVC at the existing share, `docker compose down`". The files
never move and the share never changes.
