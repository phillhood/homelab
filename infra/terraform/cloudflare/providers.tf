provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_accounts" "main" {}

locals {
  account_id = data.cloudflare_accounts.main.accounts[0].id
}
