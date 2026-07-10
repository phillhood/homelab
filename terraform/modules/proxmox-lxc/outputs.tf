output "vm_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}

output "hostname" {
  value = proxmox_virtual_environment_container.this.initialization[0].hostname
}

output "ip_address" {
  value = var.ip_address
}
