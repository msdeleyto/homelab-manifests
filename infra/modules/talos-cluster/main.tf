terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
  }
}

# ---------------------------------------------------------------------------
# Machine secrets — generated once and stored in Terraform state.
# These contain the Talos PKI, etcd encryption key, etc.
# ---------------------------------------------------------------------------
resource "talos_machine_secrets" "this" {}

# ---------------------------------------------------------------------------
# Machine configuration — one per node, templated from patches
# ---------------------------------------------------------------------------
data "talos_machine_configuration" "controlplane" {
  for_each = { for k, v in var.nodes : k => v if v.controlplane }

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_vip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
          interfaces = [
            {
              interface = "eth0"
              dhcp      = false
              addresses = [each.value.ip]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.gateway
                }
              ]
              vip = {
                ip = var.cluster_vip
              }
            }
          ]
        }
        kernel = {
          modules = [
            { name = "drbd", parameters = ["usermode_helper=disabled"] },
            { name = "drbd_transport_tcp" }
          ]
        }
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/linstor"
              type        = "bind"
              source      = "/var/lib/linstor"
              options     = ["bind", "rshared", "rw"]
            }
          ]
        }
        features = {
          qemuGuestAgent = {
            enabled = true
          }
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none" # Cilium is deployed separately
          }
        }
        proxy = {
          disabled = true # Cilium replaces kube-proxy
        }
      }
    })
  ]
}

# Apply configuration to each control plane node
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = { for k, v in var.nodes : k => v if v.controlplane }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  node                        = var.node_addresses[each.key]
  endpoint                    = var.node_addresses[each.key]
}

# ---------------------------------------------------------------------------
# Bootstrap Kubernetes — run once on the first control plane node
# ---------------------------------------------------------------------------
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_addresses[local.first_controlplane]
  endpoint             = var.node_addresses[local.first_controlplane]

  depends_on = [talos_machine_configuration_apply.controlplane]
}

# ---------------------------------------------------------------------------
# Extract kubeconfig + talosconfig after bootstrap
# ---------------------------------------------------------------------------
data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_addresses[local.first_controlplane]
  endpoint             = var.cluster_vip

  depends_on = [talos_machine_bootstrap.this]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for name, addr in var.node_addresses : addr]
  endpoints            = [var.cluster_vip]
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  first_controlplane = keys({ for k, v in var.nodes : k => v if v.controlplane })[0]
}
