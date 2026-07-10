variable "node_name" {
  type        = string
  description = "Proxmox node to create the container on"
}

variable "vm_id" {
  type        = number
  description = "Container ID"
}

variable "hostname" {
  type        = string
  description = "Container hostname"
}

variable "template_file_id" {
  type        = string
  description = "<datastore>:vztmpl/<file>"
}

variable "os_type" {
  type        = string
  description = "Container OS type"
  default     = "debian"
}

variable "ip_address" {
  type        = string
  description = "Static CIDR IP"
}

variable "gateway" {
  type        = string
  description = "Default gateway"
}

variable "cores" {
  type    = number
  default = 1
}

variable "memory" {
  type        = number
  description = "RAM in MB"
  default     = 512
}

variable "disk_size" {
  type        = number
  description = "Disk in GB"
  default     = 4
}

variable "datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "unprivileged" {
  type    = bool
  default = true
}

variable "start_on_boot" {
  type    = bool
  default = true
}

variable "ssh_public_keys" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = list(string)
  default = []
}
