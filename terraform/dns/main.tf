###############################################################################
# AO-8: DNS zapisi servisa su Terraform resursi.
#
# Zona (SOA/NS) postoji jer ju je kreirao Ansible (rola dns). Ovaj modul
# upravlja zapisima kroz RFC 2136 dynamic update, potpisanim TSIG kljucem
# koji moze mijenjati samo zone projekta.
#
# Zasto zapisi nisu u Ansible-u: ovako `terraform plan` pokazuje razliku
# izmedju zeljenog i stvarnog stanja DNS-a (drift), a `apply` je vraca.
###############################################################################

locals {
  zone_name = trimsuffix(var.zone, ".")

  # Ime zapisa -> adresa. Jedan plan adresiranja (DO-3) koristi se i ovdje,
  # i u ansible/group_vars/all.yml, i u app/.env.
  services = {
    web = var.frontend_ip
    api = var.backend_ip
    db  = var.db_ip
  }

  # PTR zapisi za reverse zone (posljednji oktet adrese je ime zapisa).
  ptrs = {
    web = {
      zone   = var.reverse_web_zone
      name   = split(".", var.frontend_ip)[3]
      target = "web.${var.zone}"
    }
    api = {
      zone   = var.reverse_web_zone
      name   = split(".", var.backend_ip)[3]
      target = "api.${var.zone}"
    }
    db = {
      zone   = var.reverse_data_zone
      name   = split(".", var.db_ip)[3]
      target = "db.${var.zone}"
    }
  }
}

# --- A zapisi --------------------------------------------------------------

resource "dns_a_record_set" "service" {
  for_each = local.services

  zone      = var.zone
  name      = each.key
  addresses = [each.value]
  ttl       = var.ttl
}

# --- PTR zapisi ------------------------------------------------------------

resource "dns_ptr_record" "service" {
  for_each = local.ptrs

  zone = each.value.zone
  name = each.value.name
  ptr  = each.value.target
  ttl  = var.ttl
}
