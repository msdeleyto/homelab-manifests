terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.12"
    }
  }
}

locals {
  first_controlplane = keys(var.nodes)[0]

  # Label conventions follow:
  #   - NFD (Node Feature Discovery) PCI labels for vendor/device detection
  #   - gpu.amd.com/* namespace for capability advertisement
  #   - amdgpu=true for backward compatibility with existing workloads
  gpu_config_patches = {
    for name, node in var.nodes : name => [
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeNodeConfig"
        labels = {
          # NFD-compatible PCI labels (matches what Node Feature Discovery
          # would generate for an AMD VGA compatible controller, vendor 1002)
          "feature.node.kubernetes.io/pci-0300_1002.present" = "true"
          "feature.node.kubernetes.io/pci-0300_1002.vendor"  = "1002"

          # Capability labels — let workloads select on GPU features
          "gpu.amd.com/present" = "true"
          "gpu.amd.com/vaapi"   = "true"

          # Backward-compatible label used by existing workloads
          "amdgpu" = "true"
        }
      }),
    ] if node.gpu_mapping != null
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
  for_each           = var.nodes
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_vip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version

  config_patches = concat(
    [
      yamlencode({
        machine = {
          network = {
            interfaces = [
              {
                interface = "eth0"
                dhcp      = false
                addresses = ["${each.value.ip}"]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = "${var.gateway}"
                  }
                ]
                vip = {
                  ip = "${var.cluster_vip}"
                }
              }
            ]
          }

          kernel = {
            modules = [
              {
                name = "drbd"
                parameters = [
                  "usermode_helper=disabled"
                ]
              },
              {
                name = "drbd_transport_tcp"
              }
            ]
          }

          kubelet = {
            extraMounts = [
              {
                destination = "/var/lib/kubelet"
                type        = "bind"
                source      = "/var/lib/kubelet"
                options     = ["rw", "rshared", "bind"]
              }
            ]
          }
        }
      }),

      # Install disk — PVE exposes the disks as /dev/sda (OS disk) and
      # /dev/sdb (LINSTOR/DRBD data disk); never /dev/vda. This is a project
      # convention — if talos-vm's disk bus ever changes, this selector must
      # be updated together with it.
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UnattendedInstallConfig"
        installer = {
          image = "factory.talos.dev/nocloud-installer/${var.talos_schematic_id}:${var.talos_version}"
        }
        provisioning = {
          diskSelector = {
            match = "disk.dev_path == \"/dev/sda\""
          }
        }
      }),

      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeFlannelCNIConfig"
        "$patch"   = "delete"
      }),

      # kube-proxy replacement is handled by Cilium.
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeProxyConfig"
        enabled    = false
      }),

      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeNodeConfig"
        taints = {
          "node-role.kubernetes.io/control-plane" = {
            "$patch" = "delete"
          }
        }
      }),

      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeletConfig"
        "$patch"   = "delete"
      }),

      # Local-path-provisioner user volume — carved from free space on the
      # system (OS) disk.  Mounted at /var/mnt/local-path-provisioner and
      # used by the Rancher Local Path Provisioner for dynamic PVCs.
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UserVolumeConfig"
        name       = "local-path-provisioner"
        provisioning = {
          diskSelector = {
            match = "system_disk"
          }
          minSize = var.local_path_volume_size
          maxSize = var.local_path_volume_size
        }
      }),
    ],

    lookup(local.gpu_config_patches, each.key, []),
  )
}

# Apply configuration to each control plane node
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = var.nodes

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
resource "talos_cluster_kubeconfig" "this" {
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
