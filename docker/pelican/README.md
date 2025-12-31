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
   - Enable SSL and Behind Proxy options

2. Copy the generated config to `/etc/pelican/config.yml`

3. Start wings:
   ```bash
   cd wings && sudo docker compose up -d
   ```

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
