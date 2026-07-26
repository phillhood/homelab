# proxy

Caddy reverse proxy running as a native systemd service in CT 104
(`proxy1`, `192.168.1.105`), holding a browser-trusted Let's Encrypt wildcard
certificate for `*.{{ lab_domain }}` and fronting every other tier0 service.

## `caddy_sha256` is drift detection, not version pinning

The Caddy download API (`caddyserver.com/api/download?...`) **ignores its own
`version=` query parameter** and always serves whatever the current latest release
happens to be. `caddy_version` in `group_vars/proxy.yaml` is therefore purely
declarative — it is referenced by nothing in this role and does not control what
`get_url` actually fetches.

What *does* control the outcome is `caddy_sha256`: `get_url`'s `checksum:` compares
the downloaded bytes against that recorded hash and **fails the converge on a
mismatch**. That failure is correct behaviour, not a bug to route around — it means
upstream shipped different bytes than the ones this role was last verified against,
and the fix is a human reviewing the new release and bumping `caddy_sha256`
deliberately, not relaxing the check. Because Caddy publishes no independently
verifiable checksum file for this build permutation either, the first fetch of a
given `caddy_sha256` is trust-on-first-use, same as `registry`'s Zot binary — see
that role's README.

One more wrinkle: `get_url` only re-checks the checksum when it actually re-fetches,
and it only re-fetches when the destination file is absent. On every ordinary
converge `/usr/local/bin/caddy` already exists, so drift detection here is a
**one-shot check at install time**, not a continuous guarantee — it will not notice
if the binary is modified out-of-band on the host afterward.

If a specific Caddy version genuinely needs to be pinned (not just "whatever
`caddy_sha256` currently points at"), the escape hatch is an `xcaddy` build shipped
by Ansible instead of the upstream download API — that gives a real, reproducible
version input. Not implemented here; this role relies on the download-API-plus-
checksum path.

## DNS-01 needs no inbound connectivity, and the token is scoped narrowly

Certificates are issued via ACME **DNS-01** through the `caddy-dns/cloudflare`
plugin baked into the fetched binary (the download URL includes
`p=github.com/caddy-dns/cloudflare`). DNS-01 proves domain control by writing a
TXT record, not by Let's Encrypt reaching back into the lab — so CT 104 needs no
inbound port opened anywhere for issuance or renewal to work, unlike HTTP-01.

`cloudflare_api_token` (`proxy.sops.yaml`) is scoped to **Zone:Read + DNS:Edit on
the single parent zone of `{{ lab_domain }}`** — it cannot read or modify any other
zone in the Cloudflare account, and it deliberately lacks `User:API Tokens:Read`, so
`cloudflare -X GET /user/tokens/verify` returns "Invalid API Token" against a
perfectly valid token. That's an expected false negative of that one endpoint, not
evidence the token is broken; the two operations this role actually needs
(`Zone:Read`, `DNS:Edit`) were verified directly instead.

## The Cloudflare token has two lives: real and validate-only

`caddy validate` renders the Caddyfile through the same `dns cloudflare
{env.CLOUDFLARE_API_TOKEN}` directive the running service uses, and the
`caddy-dns/cloudflare` provider interpolates the token verbatim into its own error
text on a provisioning failure. Running `validate:` with the real token would risk
printing it in cleartext the moment anything about the token itself is wrong.
`tasks/config.yaml`'s "Render the Caddyfile" task instead supplies
`caddy_validate_token` — a fixed placeholder — via a task-level `environment:`, so
only Caddyfile *syntax* is checked at render time; the real token
(`cloudflare_api_token`) is written straight to `caddy.env` (`no_log: true`,
`0640`, owned `root:caddy`) and only ever read by the running systemd service.
Cloudflare's provider validates a token's *shape* (length/charset) rather than its
authenticity before that point, so a placeholder of plausible shape passes
`validate:` cleanly without ever proving anything about the real credential — that
proof comes from the certificate actually issuing.

## Binary, unit and credential changes all need a restart, not a reload

`caddy reload` (`ExecReload`) tells the *running* process to re-read the Caddyfile;
it does not exec a new binary and does not re-read `EnvironmentFile=`, which
systemd only consults when it spawns the process. So a `caddy_sha256` bump or a
`cloudflare_api_token` rotation that only triggered `Reload caddy` would converge
green while the old binary or the old token stayed live in memory — a rotated
token failing silently ~60 days later at the next renewal, and a checksum bump
never actually taking effect. The binary fetch, the systemd unit template, and
`caddy.env` all notify `Restart caddy`; only the Caddyfile itself notifies
`Reload caddy`, since normal vhost edits don't need a process restart.

## `respond` catch-all vs. the real backends

`Caddyfile.j2`'s `handle {}` block (`respond "tier0 proxy ok" 200`) exists purely
so unassigned subdomains under the wildcard return something instead of a TLS
handshake with no matching site. It sits *after* `@git`/`@registry`, so as soon as
a domain has a more specific `handle` block, that block wins — `handle` blocks are
evaluated top-to-bottom and the first match serves the request. Before the
`forgejo`/`registry` roles existed, `git.{{ lab_domain }}` and
`registry.{{ lab_domain }}` both fell through to this catch-all and returned `200`
with that literal body — a `200` alone is not evidence the real backend is up; the
response body has to be checked too.
