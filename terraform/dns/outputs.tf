###############################################################################
# Outputi modula DNS: ista imena koja koristi aplikacija i testovi.
###############################################################################

output "zone" {
  description = "Forward zona projekta"
  value       = local.zone_name
}

output "fqdn" {
  description = "Ime svakog zapisa u zoni (ime -> adresa)"
  value = {
    for name, ip in local.services : "${name}.${local.zone_name}" => ip
  }
}

output "ptr" {
  description = "PTR zapisi (reverse ime -> ciljno ime)"
  value = {
    for name, rec in local.ptrs : "${rec.name}${trimsuffix(rec.zone, ".")}" => rec.target
  }
}
