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

  cluster_name       = var.cluster_name
  cluster_vip        = var.cluster_vip
  gateway            = var.gateway
  talos_version      = var.talos_version
  talos_schematic_id = var.talos_schematic_id
  nodes              = var.nodes
  node_addresses     = module.talos_vm.node_addresses

  depends_on = [module.talos_vm]
}

resource "local_sensitive_file" "kubeconfig" {
  content         = module.talos_cluster.kubeconfig_raw
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  content         = module.talos_cluster.talosconfig
  filename        = "${path.module}/talosconfig"
  file_permission = "0600"
}
