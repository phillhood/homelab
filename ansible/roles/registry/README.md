# registry

Zot pull-through cache for upstream registries, running as a native systemd service
in CT 103, fronted by Caddy at `registry.lab.shychedelic.com`.

## The binary pin is trust-on-first-use

Zot publishes no checksum file alongside its GitHub release assets — only the
binaries. `zot_sha256` in `group_vars/registry.yaml` was recorded by downloading
`zot-linux-amd64` for `v2.1.18` and hashing it by hand at role-authoring time. `get_url`'s
`checksum:` then detects any later mutation of that artifact on subsequent runs, but it
cannot verify the very first download — there is no independent source to check it
against. If GitHub ever serves a different byte stream for that URL (a re-published
release, not a CDN blip), the checksum mismatch is the operator's decision to
investigate, not something to route around.

Confirm the `-minimal` build was not fetched by accident: `zot --version` must report a
`binary-type` string containing `sync`. The minimal build omits the sync extension this
role depends on entirely, and does so without an obvious startup error.

## Config keys that differ from what most Zot docs and examples show

Verified empirically against a real v2.1.18 binary, not from documentation:

- The sync content key is **`destination`**, not `destPrefix`. `destPrefix` is rejected
  at startup with `invalid keys: destprefix`.
- The Docker Hub catch-all (`"content": [{"prefix": "**"}]`, no `destination`) must be
  **last** in `extensions.sync.registries`. It matches every image name, so any prefixed
  upstream (ghcr.io, quay.io, registry.k8s.io) listed after it becomes unreachable —
  Zot stops at the first matching registry entry.

## The cache serves without any upstream reachable

Once an image is synced, Zot serves it from local storage on subsequent pulls without
re-contacting the upstream. Verified by pointing every upstream URL in `zot_upstreams`
at a dead address and restarting Zot against the existing store: previously-cached tags
still pulled successfully. This is normal `onDemand` sync behaviour, not a bug — it
means a Docker Hub or ghcr.io outage does not take down images already cached here.

## Disk cost per image is far larger than the image itself

Measured against a real v2.1.18 instance. Pulling only `registry.k8s.io/pause:3.10`
(a single ~500 KB image by any normal measure) left **553 MB across 36 blobs** in
`/var/lib/zot/registry.k8s.io`, the two largest blobs being 290 MB and 254 MB. Zot's
sync logs show it fetching the full OCI image index for the tag — every listed
manifest, including platforms and referrers attached to `3.10` — not just the single
manifest Docker actually requested. `file` identifies the two large blobs as ordinary
tar layers, so this is not attestation/SBOM metadata; the cause was not further
isolated.

**A `tags` regex filter on the upstream does not help.** Added
`"tags": {"regex": "^3.10$"}` alongside `prefix` for the `registry.k8s.io` upstream,
wiped the store, re-pulled into it, and re-measured: identical result, 553 MB across the
same 36 blobs. This is expected in hindsight — a tags filter constrains which *tags* are
eligible to sync, not which manifests get pulled once a given tag is resolved, and the
bloat here comes from resolving a single tag, not from syncing extra tags. If per-image
disk cost needs to come down, the fix has to operate at the manifest/referrer level, not
the tag level; the 50 GB CT 103 disk should be sized assuming pulls near this order of
magnitude for images with a similar sync footprint, not their advertised image size.

Reproduce:

```bash
ssh root@192.168.1.104 'du -sh /var/lib/zot; du -sh /var/lib/zot/*'
```

## Anonymous read, no write — enforced by Zot itself, not just left unconfigured

`config.json.j2` sets `http.accessControl.repositories["**"]` to
`anonymousPolicy: [read]` / `defaultPolicy: []`. There is no `auth` extension and no
credential anywhere in this role — read stays anonymous, on purpose, for every client on
the LAN. What changed is that write is now explicitly denied rather than simply never
exercised: before this key existed, an anonymous `DELETE` against a nonexistent manifest
returned `404` (request reached the handler, no authorization check ran at all); with it,
the same request returns `401`. Verified against both paths into Zot — through Caddy at
`https://registry.lab.shychedelic.com` and directly at `http://192.168.1.104:5000` — since
Zot enforces this itself, not Caddy, so nothing about the proxy layer can be relied on to
close the direct path.

**`accessControl` is nested under `http`, not top-level.** `zot schema` (a subcommand of
the binary itself) is the authority here, not the examples in Zot's docs: a top-level
`"accessControl"` key is rejected at startup with `'config.Config' has invalid keys:
accesscontrol` and crash-loops the service. The correct shape is
`http.accessControl.repositories`, confirmed by dumping the JSON Schema with `zot schema`
and locating `AccessControlConfig` under `HTTPConfig`.

Sync/`onDemand` pull-through is unaffected, because Zot's sync workers write to storage
internally and never go through the HTTP authorization layer that rejects the anonymous
`DELETE` above. Verified by deleting a synced repository from `/var/lib/zot` outright
(not just the tag — the whole on-disk directory) and re-pulling through
`registry.lab.shychedelic.com`, for both a root-path upstream (`library/alpine:3.20`) and
a prefixed one (`registry.k8s.io/pause:3.10`): both re-populated the store from upstream
and the pulls succeeded, confirmed by `journalctl -u zot` logging `"successfully synced
image"` for each.

Nothing ever pushes to this registry through a real client — it only pulls-through and
caches upstream images on demand — so the write path being closed costs nothing in normal
operation; it only forecloses the anonymous-LAN-write posture that existed before this
key was added.

For the same reason it carries no entry in `playbooks/backups.yaml`: every byte in
`/var/lib/zot` is a re-fetchable copy of something that exists upstream, so losing
the store costs re-warming the cache on next pull, not lost data. `music_stack` and
`forgejo` back up state that exists nowhere else; `registry` deliberately does not,
by the same rule `homelab_backups/README.md` states for derived/regenerable files.
