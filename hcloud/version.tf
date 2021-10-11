terraform {
  required_providers {
    hcloud = {
      version = ">= 1.31"
      source = "terraform.local/local/hcloud"
    }
  }
  required_version = ">= 0.13"
}

provider "hcloud" {
  poll_interval = "600ms"
}

