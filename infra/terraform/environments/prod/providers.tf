terraform {
  required_version = ">= 1.9"

  backend "s3" {
    bucket = "homelab-infra"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ---------------------------------------------------------------------------
# Proxmox VE provider
# ---------------------------------------------------------------------------
provider "proxmox" {
  endpoint = var.pve_endpoint # e.g. "https://192.168.10.2:8006"
  username = var.pve_username # e.g. "terraform@pve"
  password = var.pve_password

  # Accept self-signed PVE certificates (typical for homelabs)
  insecure = true

  ssh {
    agent    = true
    username = var.pve_ssh_user # e.g. "root"
  }
}

# ---------------------------------------------------------------------------
# Talos provider — no configuration required at provider level
# ---------------------------------------------------------------------------
provider "talos" {}
