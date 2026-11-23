###############################################################################
# AO-3: adrese su outputi.
#
# Ove vrijednosti koriste Makefile (inventory za Ansible, DO-6), test skripte
# i covjek koji cita README. Nista se ne prepisuje rucno.
###############################################################################

output "vm_name" {
  description = "Ime libvirt domene"
  value       = libvirt_domain.vm.name
}

output "vm_ip" {
  description = "Fiksna adresa VM-a u upravljackoj mrezi"
  value       = var.vm_ip
}

output "admin_user" {
  description = "Korisnik za upravljanje (kreiran cloud-initom)"
  value       = var.admin_user
}

output "ssh_private_key" {
  description = "Putanja do privatnog kljuca na hostu"
  value       = local.ssh_private_key
}

output "ssh_command" {
  description = "Spremna SSH naredba za provjeru pristupa"
  value       = "ssh -i ${local.ssh_private_key} -o StrictHostKeyChecking=no ${var.admin_user}@${var.vm_ip}"
}

output "fqdn" {
  description = "Puno ime VM-a u zoni projekta"
  value       = "${var.hostname}.${var.domain}"
}
