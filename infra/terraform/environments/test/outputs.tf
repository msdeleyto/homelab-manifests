output "kubeconfig" {
  description = "Raw kubeconfig for the test cluster"
  value       = module.talos_cluster.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration for the test cluster"
  value       = module.talos_cluster.talosconfig
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path where kubeconfig was written"
  value       = "${path.module}/kubeconfig"
}
