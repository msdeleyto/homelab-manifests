output "kubeconfig" {
  description = "Raw kubeconfig for the Kubernetes cluster"
  value       = module.talos_cluster.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration"
  value       = module.talos_cluster.talosconfig
  sensitive   = true
}

output "node_ips" {
  description = "Map of node names to their static IPs"
  value       = { for name, node in var.nodes : name => split("/", node.ip)[0] }
}

output "cluster_vip" {
  description = "Kubernetes API VIP"
  value       = var.cluster_vip
}

output "kubeconfig_path" {
  description = "Path where kubeconfig was written (if written to disk)"
  value       = "${path.module}/kubeconfig"
}
