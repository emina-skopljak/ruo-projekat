terraform {
  required_version = ">= 1.5"

  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
  }
}

# RFC 2136 (dynamic update) sa TSIG kljucem. Kljuc moze mijenjati samo zone
# koje mu BIND dozvoljava (allow-update u named.conf.local) — AO-8.
provider "dns" {
  update {
    server        = var.dns_server
    port          = var.dns_port
    key_name      = var.tsig_key_name
    key_algorithm = var.tsig_key_algorithm
    key_secret    = var.tsig_secret
  }
}
