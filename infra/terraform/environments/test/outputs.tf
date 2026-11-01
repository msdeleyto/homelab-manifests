#output "kubeconfig" {
#  description = "Raw kubeconfig for the test cluster"
#  value       = module.talos_cluster.kubeconfig_raw
#  sensitive   = true
#}
#
#output "talosconfig" {
#  description = "Talos client configuration for the test cluster"
#  value       = module.talos_cluster.talosconfig
#  sensitive   = true
#}
#
#output "node_ip" {
#  description = "IP address of the single test node"
#  value       = module.talos_vm.node_addresses["talos-test-01"]
#}
#
#output "kubeconfig_path" {
#  description = "Path where kubeconfig was written"
#  value       = "${path.module}/kubeconfig"
#}
