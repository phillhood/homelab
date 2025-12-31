# Pi-hole

1. Create `.env` file:
   ```
   ADMIN_PASSWORD=password
   ```

2. Create wildcard DNS config:

   Replace `<home_domain>` and `<cluster_ip>`
      ```bash
      mkdir -p data/dnsmasq
      echo "address=/<home_domain>/<cluster_ip>" > data/dnsmasq/home-domain.conf
      ```

3. Start:
   ```bash
   sudo docker compose up -d
   ```
