resource "cloudflare_record" "home_wildcard" {
  zone_id = var.cloudflare_zone_id_home
  name    = "*.home"
  content = var.homelab_ip
  type    = "A"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "home_root" {
  zone_id = var.cloudflare_zone_id_home
  name    = "home"
  content = var.homelab_ip
  type    = "A"
  proxied = false
  ttl     = 1
}

