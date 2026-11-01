module "talos_image" {
  source = "../../modules/talos-image"

  pve_node         = var.pve_node
  pve_storage_pool = var.pve_storage_pool
  talos_version    = var.talos_version
  talos_image_url  = var.talos_image_url
  schematic_id     = var.talos_schematic_id
}

module "talos_vm" {
  source = "../../modules/talos-vm"

  pve_node         = var.pve_node
  pve_storage_pool = var.pve_storage_pool
  nodes            = var.nodes
  datastore_id     = module.talos_image.datastore_id
  image_file_id    = module.talos_image.file_id

  depends_on = [module.talos_image]
}

module "talos_cluster" {
  source = "../../modules/talos-cluster"

  cluster_name   = var.cluster_name
  cluster_vip    = var.cluster_vip
  gateway        = var.gateway
  nodes          = var.nodes
  node_addresses = module.talos_vm.node_addresses

  depends_on = [module.talos_vm]
}

# # ---------------------------------------------------------------------------
# # Bootstrap Cilium CNI
# # For the test cluster, the VIP is set to the node's own IP, so there is no
# # leader election — Cilium simply starts on the single node.
# # ---------------------------------------------------------------------------
# resource "null_resource" "deploy_cilium" {
#   depends_on = [module.talos_cluster]
# 
#   triggers = {
#     cluster_id = module.talos_cluster.cluster_id
#   }
# 
#   provisioner "local-exec" {
#     command     = <<-EOT
#       kubectl --kubeconfig <(echo '${module.talos_cluster.kubeconfig_raw}') \
#         apply -k ${var.manifests_path}/manifests/network/cilium/
#     EOT
#     interpreter = ["/bin/bash", "-c"]
#   }
# }
# 
# resource "local_sensitive_file" "kubeconfig" {
#   content         = module.talos_cluster.kubeconfig_raw
#   filename        = "${path.module}/kubeconfig"
#   file_permission = "0600"
# }
# 
# resource "local_sensitive_file" "talosconfig" {
#   content         = module.talos_cluster.talosconfig
#   filename        = "${path.module}/talosconfig"
#   file_permission = "0600"
# }
