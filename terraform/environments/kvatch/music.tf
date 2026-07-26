module "music" {
  source = "../../modules/proxmox-lxc"

  node_name        = "kvatch"
  vm_id            = 101
  hostname         = "music"
  template_file_id = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  os_type          = "debian"

  ip_address = "192.168.1.102/24"
  gateway    = "192.168.1.1"

  cores     = 2
  memory    = 4096
  disk_size = 20

  ssh_public_keys = var.ssh_public_keys

  tags = ["media", "storage"]
}
