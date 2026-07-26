module "proxy" {
  source = "../../modules/proxmox-lxc"

  node_name        = "kvatch"
  vm_id            = 104
  hostname         = "proxy"
  template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  os_type          = "debian"

  ip_address = "192.168.1.105/24"
  gateway    = "192.168.1.1"

  cores     = 1
  memory    = 512
  disk_size = 8

  ssh_public_keys = var.ssh_public_keys

  tags = ["tier0", "proxy"]
}
