terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.0"
    }
  }
  backend "remote" {
    # configurations will be initialized from backend-config
  }
}

provider "digitalocean" {
  token = var.access_token
}

provider "null" {}