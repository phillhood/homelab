variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id_home" {
  description = "Cloudflare zone ID for home domain"
  type        = string
}

variable "cloudflare_zone_id_hobby" {
  description = "Cloudflare zone ID for hobby domain"
  type        = string
}

variable "home_domain" {
  description = "Home domain"
  type        = string
}

variable "hobby_domain" {
  description = "Hobby domain"
  type        = string
}

variable "homelab_ip" {
  description = "Internal IP for Traefik ingress"
  type        = string
}
