variable "cluster_name" {
  description = "Kubernetes / Talos cluster name"
  type        = string
}

variable "cluster_vip" {
  description = "Kubernetes API VIP (Talos L2 VIP)"
  type        = string
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy (must be compatible with the Talos version)"
  type        = string
  default     = null # Null means Talos uses its bundled default
}

variable "nodes" {
  description = "Map of node definitions"
  type = map(object({
    vmid         = number
    ip           = string
    controlplane = bool
    cpu_cores    = number
    memory_mb    = number
    os_disk_gb   = number
    data_disk_gb = number
  }))
}

variable "node_addresses" {
  description = "Map of node name to IP address (from talos-vm module)"
  type        = map(string)
}
