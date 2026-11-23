###############################################################################
# Varijable (AO-3: parametri su varijable, a ne vrijednosti upisane u kod)
#
# Svaka vrijednost koja se razlikuje po racunaru ili se mijenja na odbrani
# dolazi odavde. Ime VM-a, broj jezgri, RAM, disk, adresa, korisnik, kljuc.
###############################################################################

variable "libvirt_uri" {
  description = "URI libvirt daemona (sistemski, jer nam treba NAT mreza)"
  type        = string
  default     = "qemu:///system"
}

variable "vm_name" {
  description = "Ime virtuelne masine (i osnova za imena volumena)"
  type        = string
  default     = "ruo-app"
}

variable "hostname" {
  description = "Hostname unutar VM-a (postavlja ga cloud-init)"
  type        = string
  default     = "ruo-app"
}

variable "vcpu" {
  description = "Broj virtuelnih jezgri"
  type        = number
  default     = 2

  validation {
    condition     = var.vcpu >= 1 && var.vcpu <= 8
    error_message = "vcpu mora biti izmedju 1 i 8."
  }
}

variable "memory_mb" {
  description = "RAM virtuelne masine u MB"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory_mb >= 1024
    error_message = "Za Ubuntu 24.04 treba barem 1024 MB."
  }
}

variable "disk_size_gb" {
  description = "Velicina diska VM-a u GB (qcow2 raste po potrebi)"
  type        = number
  default     = 12
}

variable "image_path" {
  description = "Putanja do Ubuntu cloud slike (izvan repoa, u kesu)"
  type        = string
  default     = "~/.cache/ruo/noble-server-cloudimg-amd64.img"
}

variable "pool_path" {
  description = "Direktorij libvirt storage pool-a na hostu"
  type        = string
  default     = "/var/lib/libvirt/images/ruo"
}

# --- mreza ---------------------------------------------------------------

variable "network_name" {
  description = "Ime libvirt mreze"
  type        = string
  default     = "ruo-net"
}

variable "network_cidr" {
  description = "Podmreza u kojoj zivi VM (host/upravljacka ravan)"
  type        = string
  default     = "192.168.100.0/24"
}

variable "network_bridge" {
  description = "Ime bridge uredjaja na hostu"
  type        = string
  default     = "virbr-ruo"
}

variable "vm_ip" {
  description = "Fiksna adresa VM-a (DHCP rezervacija po MAC adresi)"
  type        = string
  default     = "192.168.100.10"
}

variable "vm_mac" {
  description = "MAC adresa VM-a; mora odgovarati DHCP rezervaciji"
  type        = string
  default     = "52:54:00:6e:75:0a"
}

# --- pristup -------------------------------------------------------------

variable "admin_user" {
  description = "Korisnik za upravljanje koji kreira cloud-init (AO-4)"
  type        = string
  default     = "ruo"
}

variable "ssh_public_key_path" {
  description = "Javni SSH kljuc koji se ubacuje u VM (privatni ostaje van repoa)"
  type        = string
  default     = "~/.ruo/ssh/id_ruo.pub"
}

variable "ssh_private_key_path" {
  description = "Privatni kljuc (samo za ispis ssh naredbe u outputu)"
  type        = string
  default     = "~/.ruo/ssh/id_ruo"
}

variable "domain" {
  description = "DNS zona projekta (koristi se u FQDN-u VM-a)"
  type        = string
  default     = "ruo.local"
}
