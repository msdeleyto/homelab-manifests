output "file_id" {
  description = "PVE file ID of the downloaded Talos image (used as VM disk source)"
  value       = proxmox_virtual_environment_download_file.talos_image.id
}

output "datastore_id" {
  description = "PVE datastore that holds the image"
  value       = proxmox_virtual_environment_download_file.talos_image.datastore_id
}
