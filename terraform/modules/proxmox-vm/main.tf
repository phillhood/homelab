terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name          = var.name
  node_name     = var.node_name
  vm_id         = var.vmid
  tags          = var.tags
  scsi_hardware = var.scsi_hardware

  agent {
    enabled = var.qemu_agent_enabled
  }
  stop_on_destroy = true

  clone {
    vm_id = var.template_vmid
    full  = true # independent disk copy in case template changes - uses more space but safe
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type # default, see variables.tf
  }

  memory {
    dedicated = var.memory
  }

  # !! overriding size on a cloned disk resets any attribute to defaults
  # confirm settings first with `qm config <template_vmid>`
  disk {
    datastore_id = var.datastore_id
    interface    = var.disk_interface
    size         = var.disk_size
  }

  network_device {
    bridge = var.network_bridge
  }

  # leave these as defaults
  vga {
    type = var.vga_type
  }

  serial_device {
    device = var.serial_device
  }

  operating_system {
    type = var.guest_os_type
  }

  # cloud-init config
  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = var.ciuser
      keys     = var.ssh_public_keys
    }
  }
}
