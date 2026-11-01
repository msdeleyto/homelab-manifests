terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

# ---------------------------------------------------------------------------
# Provision one VM per node using for_each. Each VM gets:
#   scsi0 — OS disk (Talos system + ephemeral)
#   scsi1 — Data disk dedicated to LINSTOR/DRBD
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = var.nodes

  name      = each.key
  node_name = var.pve_node
  vm_id     = each.value.vmid

  description = "Talos Linux node — managed by Terraform"
  tags        = ["talos", "kubernetes"]

  on_boot = true
  started = true

  agent {
    enabled = true # QEMU guest agent installed via Talos extension
    trim    = true
    type    = "virtio"
    timeout = "10s"

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = each.value.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = each.value.memory_mb
  }

  # OS disk — clone from Talos image
  disk {
    datastore_id = var.pve_storage_pool
    file_id      = var.image_file_id
    interface    = "scsi0"
    size         = each.value.os_disk_gb
    discard      = "on"
    iothread     = true
    file_format  = "raw"
  }

  # Data disk — dedicated to LINSTOR/DRBD (blank, unformatted)
  disk {
    datastore_id = var.pve_storage_pool
    interface    = "scsi1"
    size         = each.value.data_disk_gb
    discard      = "on"
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
    mac_address = each.value.mac_address
  }

  # Talos boots from the cloud-init / nocloud image; no cloud-init block needed.
  # Machine config is applied via talosctl after bootstrap.

  operating_system {
    type = "l26" # Linux 6.x kernel
  }

  # Ensure clean shutdown via QEMU guest agent
  stop_on_destroy     = true
  timeout_stop_vm     = 30
  timeout_shutdown_vm = 30

  lifecycle {
    # Prevent accidental destruction if VM ID or name changes
    prevent_destroy = false
    ignore_changes  = [disk[0].file_id] # Image updates don't replace the OS disk
  }
}
