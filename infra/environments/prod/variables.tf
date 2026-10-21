# ---------------------------------------------------------------------------
# Proxmox VE
# ---------------------------------------------------------------------------
variable "pve_endpoint" {
  description = "Proxmox VE API endpoint (e.g. https://192.168.10.2:8006)"
  type        = string
}

variable "pve_username" {
  description = "Proxmox VE API username (e.g. terraform@pve)"
  type        = string
}

variable "pve_password" {
  description = "Proxmox VE API password"
  type        = string
  sensitive   = true
}

variable "pve_ssh_user" {
  description = "Proxmox VE SSH username for local-exec provisioners"
  type        = string
  default     = "root"
}

variable "pve_node" {
  description = "Proxmox VE node name to create VMs on"
  type        = string
  default     = "pve01"
}

variable "pve_storage_pool" {
  description = "PVE storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

# ---------------------------------------------------------------------------
# Talos Image
# ---------------------------------------------------------------------------
variable "talos_version" {
  description = "Talos Linux version (e.g. v1.9.0)"
  type        = string
}

variable "talos_schematic_id" {
  description = "Talos Image Factory schematic ID (includes qemu-agent, amd-ucode, drbd extensions)"
  type        = string
}

variable "talos_image_url" {
  description = "Direct download URL for the Talos nocloud image from the Image Factory"
  type        = string
}

# ---------------------------------------------------------------------------
# Cluster Nodes
# ---------------------------------------------------------------------------
variable "nodes" {
  description = "Map of Talos node definitions. Each key becomes the VM hostname."
  type = map(object({
    vmid         = number
    ip           = string # Static IP in CIDR notation, e.g. "192.168.10.50/24"
    controlplane = bool
    cpu_cores    = number
    memory_mb    = number
    os_disk_gb   = number
    data_disk_gb = number
  }))
  default = {
    "talos-01" = {
      vmid         = 101
      ip           = "192.168.10.50/24"
      controlplane = true
      cpu_cores    = 4
      memory_mb    = 8192
      os_disk_gb   = 64
      data_disk_gb = 500
    }
    "talos-02" = {
      vmid         = 102
      ip           = "192.168.10.51/24"
      controlplane = true
      cpu_cores    = 4
      memory_mb    = 8192
      os_disk_gb   = 64
      data_disk_gb = 500
    }
    "talos-03" = {
      vmid         = 103
      ip           = "192.168.10.52/24"
      controlplane = true
      cpu_cores    = 4
      memory_mb    = 8192
      os_disk_gb   = 64
      data_disk_gb = 500
    }
  }
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "gateway" {
  description = "Default gateway IP"
  type        = string
  default     = "192.168.10.1"
}

variable "cluster_vip" {
  description = "Kubernetes API VIP (Talos L2 VIP, shared across control plane nodes)"
  type        = string
  default     = "192.168.10.80"
}

variable "cluster_name" {
  description = "Kubernetes / Talos cluster name"
  type        = string
  default     = "homelab"
}

# ---------------------------------------------------------------------------
# Bootstrap path
# ---------------------------------------------------------------------------
variable "manifests_path" {
  description = "Absolute path to the homelab-manifests repository root on the machine running Terraform"
  type        = string
}
