# Homelab

***v2!***

Proxmox VE on one node, with a cluster planned. Terraform provisions the guests, Ansible
configures them, and nothing in `ansible/` creates or destroys a guest.

## Layout

| | |
|---|---|
| `terraform/` | provisions guests — containers and VMs |
| `ansible/` | configures what Terraform created |
| `kubernetes/` | cluster manifests — Phase 5, not live yet |
| `.docs/` | hardware, network, services, roadmap — local only |

## Running it

Everything goes through the Makefile.

```bash
make help        # every target
make lint        # syntax + ansible-lint, contacts nothing
make check       # dry run with diffs — what WOULD change
make apply       # converge
make verify      # read-only health probes against every system
make backup      # every backup series
```

The safe path is `make preflight` — lint, take a backup, show the diff — then `make apply`.

Narrow any target with `LIMIT=` and `TAGS=`, e.g. `make check LIMIT=pihole TAGS=config`.

## Docs

| | |
|---|---|
| [`.docs/HARDWARE.md`](.docs/HARDWARE.md) | nodes, guests, storage |
| [`.docs/NETWORK.md`](.docs/NETWORK.md) | topology, DNS, request path, known gaps |
| [`.docs/SERVICES.md`](.docs/SERVICES.md) | what runs where, and the tier doctrine |
| [`.docs/TODO.md`](.docs/TODO.md) | roadmap by phase, and what is blocked |
