variable "pve_node" {
  description = "Proxmox VE node name"
  type        = string
}

variable "pve_storage_pool" {
  description = "PVE storage pool for VM disks"
  type        = string
}

variable "talos_version" {
  description = "Talos Linux version string (e.g. v1.9.0)"
  type        = string
}

variable "talos_image_url" {
  description = "Direct download URL for the Talos nocloud image"
  type        = string
}

variable "schematic_id" {
  description = "Talos Image Factory schematic ID"
  type        = string
}
