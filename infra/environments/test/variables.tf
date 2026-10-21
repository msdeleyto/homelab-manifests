# ---------------------------------------------------------------------------
# Proxmox VE
# ---------------------------------------------------------------------------
variable "pve_endpoint" {
  description = "Proxmox VE API endpoint (e.g. https://192.168.10.2:8006)"
  type        = string
}

variable "pve_username" {
  description = "Proxmox VE API username"
  type        = string
}

variable "pve_password" {
  description = "Proxmox VE API password"
  type        = string
  sensitive   = true
}

variable "pve_ssh_user" {
  description = "SSH user on PVE host"
  type        = string
  default     = "root"
}

variable "pve_node" {
  description = "Proxmox VE node name"
  type        = string
  default     = "pve01"
}

variable "pve_storage_pool" {
  description = "PVE storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "cpu_type" {
  description = "QEMU CPU type for VMs inside the test Proxmox instance. Since test Proxmox runs as a VM, use 'kvm64' or 'host' (if nested virt is enabled with host-passthrough)."
  type        = string
  default     = "kvm64"
}

# ---------------------------------------------------------------------------
# Talos Image — reuses the same image as prod (no re-download if present)
# ---------------------------------------------------------------------------
variable "talos_version" {
  description = "Talos Linux version (e.g. v1.9.0)"
  type        = string
}

variable "talos_schematic_id" {
  description = "Talos Image Factory schematic ID"
  type        = string
}

variable "talos_image_url" {
  description = "Direct download URL for the Talos nocloud image"
  type        = string
}

# ---------------------------------------------------------------------------
# Cluster — single node, lighter resources
# ---------------------------------------------------------------------------
variable "nodes" {
  description = "Map of Talos node definitions. Single entry for the test environment."
  type = map(object({
    vmid         = number
    ip           = string
    controlplane = bool
    cpu_cores    = number
    memory_mb    = number
    os_disk_gb   = number
    data_disk_gb = number
  }))
  # Single VM: CP + worker, lower resources, higher VMID range (200s)
  default = {
    "talos-test-01" = {
      vmid         = 201
      ip           = "192.168.10.60/24"
      controlplane = true
      cpu_cores    = 4
      memory_mb    = 8192
      os_disk_gb   = 64
      data_disk_gb = 100
    }
  }
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
  default     = "192.168.10.1"
}

# No VIP needed for single-node — use the node IP directly as the API endpoint
variable "cluster_vip" {
  description = "Kubernetes API endpoint IP. For single-node test clusters, set this to the node's own IP (no VIP election needed)."
  type        = string
  default     = "192.168.10.60"
}

variable "cluster_name" {
  description = "Talos cluster name"
  type        = string
  default     = "homelab-test"
}

variable "manifests_path" {
  description = "Absolute path to the homelab-manifests repository root"
  type        = string
}
