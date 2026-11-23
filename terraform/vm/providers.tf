terraform {
  required_version = ">= 1.5"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# qemu:///system jer nam treba libvirt NAT mreza (virbr) sa stabilnom adresom
# i direktnim pristupom hosta do VM-a (Ansible, Terraform DNS provider).
provider "libvirt" {
  uri = var.libvirt_uri
}

provider "local" {}
