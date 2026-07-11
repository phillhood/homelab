variable "name" {
  description = "VM name, also hostname"
  type        = string
}

variable "vmid" {
  description = "VMID - use 100-199"
  type        = number
}

variable "node_name" {
  description = "Target Proxmox node"
  type        = string
  default     = "kvatch"
}

variable "template_vmid" {
  description = "VMID of the cloud-init template to clone"
  type        = number
  default     = 9000
}

variable "cores" {
  description = "Number of vCPU cores"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "Template 9000 uses 'host' - passthrough, best performance but ties to host node - revisit if multiple nodes"
  type        = string
  default     = "host"
}

variable "memory" {
  description = "Dedicated memory in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "GB, additive with 3G base"
  type        = number
  default     = 16
}

variable "disk_interface" {
  description = "Boot disk interface inherited from template"
  type        = string
  default     = "scsi0"
}

variable "datastore_id" {
  description = "Datastore for the boot disk and cloud-init drive"
  type        = string
  default     = "local-lvm"
}

variable "scsi_hardware" {
  description = "SCSI controller type - must match the template"
  type        = string
  default     = "virtio-scsi-single"
}

variable "ip_address" {
  description = "Static IP in CIDR notation - eg. 192.168.1.102/24"
  type        = string
}

variable "gateway" {
  description = "IPv4 gateway"
  type        = string
  default     = "192.168.1.1"
}

variable "network_bridge" {
  description = "Proxmox bridge for VM NIC"
  type        = string
  default     = "vmbr0"
}

variable "ciuser" {
  description = "Cloud-init user account"
  type        = string
  default     = "phill"
}

variable "ssh_public_keys" {
  description = "SSH public keys injected via cloud-init"
  type        = list(string)
}

variable "tags" {
  description = "VM tags — keep alphabetically sorted!"
  type        = list(string)
  default     = []
}

variable "qemu_agent_enabled" {
  description = "Enable QEMU guest agent link. Keep false until qemu-guest-agent running"
  type        = bool
  default     = false
}

# below 3 vars are unlikely to change, but worth the consistency + self-documentation of descriptions
variable "vga_type" {
  description = "VGA type - serial0 default for headless, only change if cloning a template with display."
  type        = string
  default     = "serial0"
}

variable "serial_device" {
  description = "Serial device backing console - when headless, 'socket' allows hypervisor to attach via unix domain socket (IPC)"
  type        = string
  default     = "socket"
}

variable "guest_os_type" {
  description = "Guest OS type hint passed to Proxmox - Convention: Linux kernel 2.6+ -> l26"
  type        = string
  default     = "l26"
}

