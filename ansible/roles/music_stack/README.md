# music_stack

Docker Engine plus the slskd / museek compose stack in CT 101.

## Usage

| Tag | Does |
|---|---|
| `docker` | Docker Engine + compose plugin from Docker's own apt repo |
| `compose` | renders `docker-compose.yml` and brings the stack up |
| `stack` | both |

Docker needs `nesting=1` and `keyctl=1`, set on the container by
`music_storage/tasks/container_mount.yaml` via `pct set`. Installation succeeding proves
nothing — the real test is:

```bash
ssh root@192.168.1.102 'docker run --rm hello-world'
```

If that hangs or errors on cgroups or the keyring, a feature flag is missing or the
container has not been rebooted since it was set.

Both compose invocations carry `no_log: true`, because the rendered file holds secrets and a
YAML parse error echoes the offending line. To see what actually went wrong, run it by hand:

```bash
ssh root@192.168.1.102 'cd /opt/music-stack && docker compose up -d'
```

## Variables

| Variable | Default | Notes |
|---|---|---|
| `music_app_image` | `""` | museek. Empty omits the service — this is the deploy gate |
| `music_discord_image` | `""` | museek-discord, same gate |
| `music_slskd_image` | `slskd/slskd:0.26.0` | |
| `music_slskd_listen_port` | `2235` | Soulseek listen port; needs the OPNsense forward |
| `music_museek_port` | `8080` | |
| `music_museek_match_threshold` | `"0.6"` | museek's real quality gate |

**Requires** from `music.sops.yaml`: `slskd_soulseek_username`/`_password`,
`slskd_web_username`/`_password`, `museek_slskd_api_key`, `museek_api_token`,
`museek_spotify_client_id`/`_secret`, `museek_discord_token`, `museek_discord_guild_id`,
`museek_discord_channel_id`. Plus `museek_musicbrainz_contact` from `group_vars/music.yaml`
whenever `music_app_image` is set.

## Invariants

- **Placeholder Soulseek credentials are refused, and this is not theoretical.** Soulseek has
  no registration step — the first login with an unused name *claims* it. Deploying with
  placeholders once registered a live public account named `FILL_ME` on the real network from
  this house's IP. It shared nothing and was stopped, but the name stays claimed.
- **`music_app_image` and `music_discord_image` empty is a feature, not an unset value.** The
  compose template omits the matching service entirely, so clearing one is the supported way
  to take a service out without editing the template. Do not "fix" them with an assert.
- **Bind mounts, never named volumes.** A named volume initialises from the museek image's
  uid 10001 and becomes unwritable under the `user: "1500:1500"` override.
- **The `:ro` on slskd's library mount is load-bearing.** slskd shares the library back to
  Soulseek without ever being able to modify it. Prove it:
  `docker exec slskd touch /library/x` must fail.
- **The Docker signing key is fetched with `force: true` deliberately.** `get_url` otherwise
  skips the download whenever the destination exists, comparing nothing — so an upstream key
  rotation would leave the stale copy in place and apt would fail signature verification with
  no automated recovery. It still only reports `changed` when the content differs, so
  idempotent runs stay clean.
- **One API key, two names.** `museek_slskd_api_key` renders as both museek's
  `MUSEEK_SLSKD_API_KEY` and slskd's own `SLSKD_API_KEY`, so they are equal by construction.
  Never configure a second key.
- **slskd's incomplete directory is deliberately not mounted.** slskd does not auto-create
  non-default directories, and pointing it at a freshly created shared mount can leave it
  unable to start, after which museek blocks forever on `depends_on: service_healthy`.
  `/srv/music/downloads/incomplete/` exists on the SSD and is intentionally unused.
- `/var/lib/docker` stays on the container root disk, keeping the container disposable and
  the media disk pure data. Verify: `findmnt -no TARGET -T /var/lib/docker` returns `/`.

`2235/tcp` is the only external exposure in this design and needs a **manual** OPNsense port
forward (Firewall → NAT → Port Forward, WAN, TCP, `2235` → `192.168.1.102:2235`). Without
it slskd falls back to indirect connections and download reliability drops noticeably.

Rationale, the SLSKD_UMASK mechanism and the museek 0.1.0 crash-loop:
`.dev/docs/ansible/music_stack.md`.
