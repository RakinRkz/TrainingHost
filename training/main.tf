terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_ssh_key" "controller" {
  name       = "controller-gpu-ssh-key"
  public_key = file("~/.ssh/id_rsa_do_controller.pub")
}

resource "digitalocean_droplet" "gpu_training" {
  name     = "gpu-training-droplet"
  region   = "ams3"  # Amsterdam
  size     = "gpu-h100x1-80gb"
  image    = "gpu-h100x1-base"
  ssh_keys = [digitalocean_ssh_key.controller.id]
}

output "droplet_ip" {
  value = digitalocean_droplet.gpu_training.ipv4_address
}