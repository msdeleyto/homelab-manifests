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

variable "talos_version" {
  description = "Talos Linux version used by the Image Factory image"
  type        = string
}

variable "talos_schematic_id" {
  description = "Talos Image Factory schematic ID used for installation"
  type        = string
}

variable "nodes" {
  description = "Map of node definitions (control-plane only; extra attributes passed by callers are ignored)"
  type = map(object({
    ip           = string
    controlplane = bool
  }))

  validation {
    condition     = length(var.nodes) > 0
    error_message = "At least one node must be defined."
  }

  validation {
    condition     = alltrue([for _, v in var.nodes : v.controlplane])
    error_message = "This module only supports control-plane nodes; every entry must have controlplane = true."
  }
}

variable "node_addresses" {
  description = "Map of node name to IP address without prefix length (from talos-vm module)"
  type        = map(string)

  validation {
    condition = alltrue([
      for k in keys(var.nodes) : contains(keys(var.node_addresses), k)
    ])
    error_message = "node_addresses must contain an entry for every node defined in nodes."
  }
}
