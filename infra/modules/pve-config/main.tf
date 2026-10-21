terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

# ---------------------------------------------------------------------------
# PVE host-level configuration: APT repositories, Terraform API user + token,
# ACLs, and storage pool definitions.
#
# These are one-time resources that only need to exist once per PVE node.
# ---------------------------------------------------------------------------

resource "proxmox_virtual_environment_apt_standard_repository" "no_subscription" {
  node   = var.pve_node
  handle = "no-subscription"
}

resource "proxmox_virtual_environment_apt_standard_repository" "ceph_no_subscription" {
  node   = var.pve_node
  handle = "ceph-no-subscription"
}

# Dedicated API user for Terraform (least privilege)
resource "proxmox_virtual_environment_user" "terraform" {
  comment = "Managed by Terraform"
  email   = "terraform@homelab"
  enabled = true
  user_id = "terraform@pve"
}

resource "proxmox_virtual_environment_role" "terraform" {
  role_id = "TerraformProv"
  privileges = [
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Pool.Allocate",
    "Sys.Audit",
    "Sys.Console",
    "Sys.Modify",
    "VM.Allocate",
    "VM.Audit",
    "VM.Clone",
    "VM.Config.CDROM",
    "VM.Config.Cloudinit",
    "VM.Config.CPU",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Meta",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.Migrate",
    "VM.Monitor",
    "VM.PowerMgmt",
  ]
}

resource "proxmox_virtual_environment_acl" "terraform_root" {
  path      = "/"
  role_id   = proxmox_virtual_environment_role.terraform.role_id
  user_id   = proxmox_virtual_environment_user.terraform.user_id
  propagate = true
}

resource "proxmox_virtual_environment_api_token" "terraform" {
  comment               = "Terraform provisioner token"
  token_name            = "terraform"
  user_id               = proxmox_virtual_environment_user.terraform.user_id
  privileges_separation = false
}
