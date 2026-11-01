variable "pve_node" {
  description = "Proxmox VE node name"
  type        = string
}

variable "cpu_type" {
  description = "QEMU CPU type for VMs. Use 'x86-64-v2-AES' on bare-metal PVE. Use 'kvm64' when PVE itself runs inside a VM (nested virtualisation)."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "pve_storage_pool" {
  description = "PVE storage pool for VM disks"
  type        = string
}

variable "nodes" {
  description = "Map of node definitions (same shape as root module)"
  type = map(object({
    vmid         = number
    ip           = string
    controlplane = bool
    cpu_cores    = number
    memory_mb    = number
    os_disk_gb   = number
    data_disk_gb = number
    mac_address  = string
  }))
}

variable "image_file_id" {
  description = "PVE file ID of the Talos image (from talos-image module)"
  type        = string
}

variable "datastore_id" {
  description = "PVE datastore holding the Talos image"
  type        = string
}
