module "pihole" {
  source = "../../modules/proxmox-lxc"

  node_name        = "kvatch"
  vm_id            = 100
  hostname         = "pihole"
  template_file_id = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  os_type          = "debian"

  ip_address = "192.168.1.100/24"
  gateway    = "192.168.1.1"

  cores     = 1
  memory    = 512
  disk_size = 4

  ssh_public_keys = var.ssh_public_keys

  tags = ["dns", "infra"]
}
