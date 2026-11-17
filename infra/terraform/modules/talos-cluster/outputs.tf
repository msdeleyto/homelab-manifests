output "kubeconfig_raw" {
  description = "Raw kubeconfig YAML for the cluster"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration YAML"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_id" {
  description = "Stable cluster identifier (used to trigger dependent resources)"
  value       = talos_machine_secrets.this.id
}
