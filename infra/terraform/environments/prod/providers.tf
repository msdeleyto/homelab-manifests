terraform {
  required_version = ">= 1.9"

  backend "s3" {
    bucket = "homelab-infra"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"

    # State contains full Talos cluster secrets (machine Secrets, etcd keys).
    encrypt = true
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
  endpoint = var.pve_endpoint
  api_token = var.pve_api_token
  insecure  = true

  ssh {
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")
  }
}

# ---------------------------------------------------------------------------
# Talos provider — no configuration required at provider level
# ---------------------------------------------------------------------------
provider "talos" {}
