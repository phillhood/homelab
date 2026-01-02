# Pelican

Game server management panel using Pelican Panel and Wings.

## Panel Setup

1. Start panel:
   ```bash
   cd panel && sudo docker compose up -d
   ```

2. Complete the web installer at your panel URL `/installer`

## Wings Setup

1. Create a Node in the Panel admin UI:
   - FQDN: `wings.home.pharah.ca`
   - Communicate over SSL: **OFF** (Panel connects directly via HTTP)
   - Behind Proxy: **ON** (browser uses HTTPS via Traefik)
   - Daemon Port: `8080`

2. Copy the generated config to `/etc/pelican/config.yml`

3. Add trusted proxies to `/etc/pelican/config.yml`:
   ```yaml
   trusted_proxies:
     - 192.168.2.100
     - 10.42.0.0/16
   ```

4. Start wings:
   ```bash
   cd wings && sudo docker compose up -d
   ```

## Network Architecture

Panel and Wings run on the same host (kvatch). To avoid timeout issues:
- Panel connects to Wings directly via HTTP on port 8080
- Browser connects to Wings via Traefik (HTTPS) for websockets
- `extra_hosts` in Panel's docker-compose maps `wings.home.pharah.ca` to the Docker host

## Directory Structure

```
pelican/
├── panel/
│   ├── docker-compose.yaml
│   └── .env
└── wings/
    └── docker-compose.yaml
```

Wings config and data are stored in system directories:
- `/etc/pelican/` - Wings configuration
- `/var/lib/pelican/` - Game server data
- `/var/log/pelican/` - Logs
