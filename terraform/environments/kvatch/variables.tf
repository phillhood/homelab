variable "pve_endpoint" {
  type = string
}

variable "pve_api_token" {
  type      = string
  sensitive = true
}

variable "ssh_public_keys" {
  type    = list(string)
  default = []
}
