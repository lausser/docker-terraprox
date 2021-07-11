terraform {
  required_version = ">= 0.13"
  required_providers {
    proxmox = {
      version = ">= 1.0.0"
      source  = "terraform.local/local/proxmox"
    }
  }
}
