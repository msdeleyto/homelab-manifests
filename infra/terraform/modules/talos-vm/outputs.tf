output "node_addresses" {
  description = "Map of node name to its IP address (without prefix length)"
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos :
    name => split("/", var.nodes[name].ip)[0]
  }
}

output "vm_ids" {
  description = "Map of node name to PVE VM ID"
  value = {
    for name, vm in proxmox_virtual_environment_vm.talos :
    name => vm.vm_id
  }
}
