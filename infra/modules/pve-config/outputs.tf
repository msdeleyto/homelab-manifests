output "api_token" {
  description = "Terraform API token value (sensitive)"
  value       = proxmox_virtual_environment_api_token.terraform.value
  sensitive   = true
}
