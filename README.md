# Homelab

> [!NOTE]
> Archived - [I've moved on to v2!](/main/README.md)
> 

My homelab setup for home apps and services, and faffing around with DevOps and Networking

## Stack

### k3s Cluster
  - ***Sealed Secrets*** for secrets
  - ***Traefik*** for ingress
  - ***Prometheus*** for metrics
  - ***Grafana*** for dashboards
  - ***Loki*** for logs
  - ***Cloudflare Tunnel*** for serving web apps
  - ***Cloudflare DDNS*** for game server domains (with port fowarding)
  - ***Cert Manager*** for certificates
  - ***Zot*** for local registry + charts

### Docker
  - ***Pihole*** for DCHP+DNS
  - ***Pelican*** for game servers


### Infrastructure
  - ***Ansible*** for device orchestration
  - ***Terraform*** for Cloudflare resources

## Structure

```
homelab/
├── infra/
│   ├── ansible/     # Node provisioning
│   └── terraform/   # Cloudflare tunnel/DDNS
├── k8s/             # Kubernetes manifests (Helm umbrella chart)
│   └── apps/
│       ├── core/    # Cluster essentials
│       ├── media/   # Media services
│       ├── gaming/  # Game services
│       └── web/     # Web apps
└── docker/          # Docker services
```

## Nodes

| Name | Role | 
|------|------|
| cyrodiil | control-plane |
| kvatch | worker |
| bruma | worker |
| anvil | worker |
| bravil | playground |


More nodes coming soon when I inevitably make poor financial decisions.

## Quick Start

- [Ansible](infra/ansible/README.md)
- [Terraform](infra/terraform/cloudflare/README.md)
- [Kubernetes](k8s/README.md)
