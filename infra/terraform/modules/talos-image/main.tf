terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

# ---------------------------------------------------------------------------
# Download the Talos nocloud image from the Image Factory directly into
# Proxmox storage via the PVE API. This avoids downloading it manually.
# ---------------------------------------------------------------------------

resource "proxmox_download_file" "this" {
  node_name    = var.pve_node
  content_type = "iso"
  datastore_id = "local" # PVE "local" datastore holds ISO/template images

  file_name = "talos-${var.talos_version}-${var.schematic_id}-nocloud-amd64.iso"
  url       = var.talos_image_url
  overwrite = false
}
