# proxy

Caddy in CT 104, holding a browser-trusted Let's Encrypt wildcard certificate for
`*.{{ lab_domain }}` and fronting every other tier0 service. TLS terminates here, once.

## Usage

| Tag | Does |
|---|---|
| `install` | user, directories, the binary, `cap_net_bind_service`, the systemd unit |
| `config` | the Cloudflare env file, the Caddyfile, enable + start |
| `caddy` | both |

Certificates are issued via ACME **DNS-01** through the `caddy-dns/cloudflare` plugin baked
into the fetched binary. DNS-01 proves domain control by writing a TXT record, so CT 104
needs no inbound port opened anywhere for issuance or renewal — unlike HTTP-01.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `caddy_version` | `group_vars/proxy.yaml` | declarative only — see invariants |
| `caddy_sha256` | — | the real gate |
| `caddy_download_url` | Caddy's download API, with the cloudflare plugin | |
| `caddy_acme_email` | — | **required** |
| `forge_backend`, `registry_backend` | — | **required**, `host:port` |
| `caddy_validate_token` | a fixed placeholder | never the real token; see invariants |

**Requires** `cloudflare_api_token` from `proxy.sops.yaml`, scoped to **Zone:Read +
DNS:Edit on the single parent zone** of `{{ lab_domain }}`.

## Invariants

- **`caddy_version` controls nothing.** The download API ignores its own `version=`
  parameter and always serves the current release. `caddy_sha256` is what actually gates the
  outcome: `get_url` fails the converge on a mismatch. That failure is correct behaviour —
  upstream shipped different bytes than were last verified — and the fix is a human
  reviewing the release and bumping the hash, not relaxing the check.
- **Drift detection here is one-shot, at install time.** `get_url` only re-checks the
  checksum when it re-fetches, and it only re-fetches when the destination is absent. It will
  not notice a binary modified out-of-band afterwards.
- **`validate:` must never see the real Cloudflare token.** The `caddy-dns/cloudflare`
  provider interpolates the token verbatim into its own error text on a provisioning
  failure, so validating with the real one risks printing it in cleartext. `config.yaml`
  supplies `caddy_validate_token`, a fixed placeholder, via a task-level `environment:` — so
  only Caddyfile *syntax* is checked. The real token goes straight to `caddy.env`
  (`no_log`, `0640`, `root:caddy`) and is only ever read by the running service.
- **Binary, unit and credential changes need a restart, not a reload.** `caddy reload` tells
  the running process to re-read the Caddyfile; it does not exec a new binary and does not
  re-read `EnvironmentFile=`, which systemd consults only when it spawns the process. A
  `caddy_sha256` bump or a token rotation that only triggered `Reload caddy` would converge
  green while the old binary or old token stayed live — the rotated token failing silently
  ~60 days later at the next renewal. Only the Caddyfile itself notifies `Reload caddy`.
- **The catch-all `handle {}` returns `200` with body `tier0 proxy ok`** for any subdomain
  with no more specific block ahead of it. So a `200` from any lab hostname proves nothing
  about the backend — check the body.
- `cloudflare -X GET /user/tokens/verify` returns "Invalid API Token" against a perfectly
  valid token, because the token deliberately lacks `User:API Tokens:Read`. That is an
  expected false negative of that one endpoint, not evidence the token is broken.

Rationale and the xcaddy escape hatch are in the local notes for this role.
