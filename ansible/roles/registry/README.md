# registry

Zot pull-through cache for upstream registries, running as a native systemd service in
CT 103, fronted by Caddy at `registry.{{ lab_domain }}`.

## Usage

| Tag | Does |
|---|---|
| `install` | user, directories, the binary, the systemd unit |
| `config` | renders `config.json`, enables and starts |
| `zot` | both |

Nothing ever pushes here. It only pulls through and caches on demand, so there is no
credential anywhere in this role and no entry in `playbooks/backups.yaml` — every byte in
`/var/lib/zot` is a re-fetchable copy of something upstream.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `zot_version`, `zot_sha256` | `group_vars/registry.yaml` | bump together; see invariants |
| `zot_upstreams` | ghcr.io, quay.io, registry.k8s.io | prefixed upstreams |
| `zot_dockerhub_url` | `https://registry-1.docker.io` | the catch-all |
| `zot_port` | `5000` | |
| `zot_user`, `zot_config_dir`, `zot_data_dir` | `zot`, `/etc/zot`, `/var/lib/zot` | |

## Invariants

- **The Docker Hub catch-all must be last in `extensions.sync.registries`.** Its content
  entry is `{"prefix": "**"}` with no `destination`, so it matches every image name — any
  prefixed upstream listed after it becomes unreachable, because Zot stops at the first
  matching registry entry.
- **`accessControl` is nested under `http`, not top-level.** A top-level `"accessControl"`
  key is rejected at startup with `'config.Config' has invalid keys: accesscontrol` and
  crash-loops the service. `zot schema` is the authority here, not the examples in Zot's
  docs.
- **The sync content key is `destination`, not `destPrefix`.** `destPrefix` is rejected at
  startup with `invalid keys: destprefix`.
- **Anonymous read, no write — and the deny is explicit, not merely unconfigured.**
  `http.accessControl.repositories["**"]` sets `anonymousPolicy: [read]` and
  `defaultPolicy: []`. Zot enforces this itself, not Caddy, so the direct path at
  `:5000` is closed too — nothing about the proxy layer can be relied on for it.
- **`zot_sha256` is trust-on-first-use.** Zot publishes no checksum file alongside its
  release assets, so the recorded hash was taken by hand at authoring time. `get_url`'s
  `checksum:` then detects any later mutation, but cannot verify the first download. A
  mismatch is an operator decision to investigate, never something to route around.
- **Confirm the `-minimal` build was not fetched by accident.** `zot --version` must report a
  `binary-type` containing `sync`. The minimal build omits the sync extension this role
  depends on entirely, and does so with no obvious startup error.
- Disk cost per image is far larger than the image itself — pulling only
  `registry.k8s.io/pause:3.10` left 553 MB across 36 blobs. Size CT 103 accordingly; a `tags`
  regex filter does **not** help.

```bash
ssh root@192.168.1.104 'du -sh /var/lib/zot; du -sh /var/lib/zot/*'
```

Rationale and the measurements: `.dev/docs/ansible/registry.md`.
