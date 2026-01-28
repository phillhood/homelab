resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = local.account_id
  name       = "homelab"
  secret     = random_id.tunnel_secret.b64_std

  lifecycle {
    ignore_changes = [secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config {
    ingress_rule {
      hostname = var.hobby_domain
      service  = "https://traefik.kube-system.svc.cluster.local:443"
      origin_request {
        no_tls_verify = true
      }
    }
    ingress_rule {
      hostname = "*.${var.hobby_domain}"
      service  = "https://traefik.kube-system.svc.cluster.local:443"
      origin_request {
        no_tls_verify = true
      }
    }
    ingress_rule {
      hostname = var.home_domain
      service  = "https://traefik.kube-system.svc.cluster.local:443"
      origin_request {
        no_tls_verify = true
      }
    }
    ingress_rule {
      hostname = "*.${var.home_domain}"
      service  = "https://traefik.kube-system.svc.cluster.local:443"
      origin_request {
        no_tls_verify = true
      }
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "hobby_tunnel" {
  zone_id         = var.cloudflare_zone_id_hobby
  name            = "@"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "hobby_www_tunnel" {
  zone_id         = var.cloudflare_zone_id_hobby
  name            = "www"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "home_tunnel" {
  zone_id         = var.cloudflare_zone_id_home
  name            = "@"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "home_www_tunnel" {
  zone_id         = var.cloudflare_zone_id_home
  name            = "www"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "home_vpn_tunnel" {
  zone_id         = var.cloudflare_zone_id_home
  name            = "vpn"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_record" "home_headscale_tunnel" {
  zone_id         = var.cloudflare_zone_id_home
  name            = "headscale"
  content         = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  allow_overwrite = true
}

resource "cloudflare_zero_trust_access_application" "headscale_ui" {
  account_id                = local.account_id
  name                      = "Headscale Admin"
  domain                    = "headscale.${var.home_domain}"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
}

resource "cloudflare_zero_trust_access_policy" "headscale_ui" {
  account_id     = local.account_id
  application_id = cloudflare_zero_trust_access_application.headscale_ui.id
  name           = "Allow admin emails"
  precedence     = 1
  decision       = "allow"

  include {
    email = [var.admin_email]
  }
}

output "tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.homelab.tunnel_token
  sensitive = true
}
