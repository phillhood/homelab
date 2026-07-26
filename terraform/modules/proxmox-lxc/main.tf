terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  unprivileged  = var.unprivileged
  start_on_boot = var.start_on_boot
  started       = true
  tags          = var.tags

  lifecycle {
    ignore_changes = [
      features,
      mount_point,
      operating_system[0].template_file_id,
    ]
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  network_interface {
    name   = "veth0"
    bridge = var.bridge
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }
}
