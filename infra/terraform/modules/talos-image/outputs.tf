output "file_id" {
  description = "PVE file ID of the downloaded Talos image (used as VM disk source)"
  value       = proxmox_download_file.this.id
}

output "datastore_id" {
  description = "PVE datastore that holds the image"
  value       = proxmox_download_file.this.datastore_id
}
