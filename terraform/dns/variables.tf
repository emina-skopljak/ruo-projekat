###############################################################################
# Varijable (AO-3 princip: parametri su varijable, ne upisane vrijednosti).
#
# Adresa DNS servera se NE prepisuje rucno: dolazi iz Terraform outputa
# modula terraform/vm preko remote state-a (DO-6).
###############################################################################

variable "dns_server" {
  description = "Adresa BIND servera; Makefile je popunjava iz 'terraform output' modula vm (DO-6)"
  type        = string
  default     = "192.168.100.10"
}

variable "dns_port" {
  description = "Port BIND servera za dynamic update"
  type        = number
  default     = 53
}

variable "tsig_key_name" {
  description = "Ime TSIG kljuca (mora odgovarati named.conf.local)"
  type        = string
  default     = "ruo-key."
}

variable "tsig_key_algorithm" {
  description = "TSIG algoritam"
  type        = string
  default     = "hmac-sha256"
}

variable "tsig_secret" {
  description = "TSIG secret; postavlja se kroz TF_VAR_tsig_secret iz ~/.ruo/tsig.key (AO-9)"
  type        = string
  sensitive   = true
  default     = ""
}

# --- zona i zapisi ---

variable "zone" {
  description = "Forward zona projekta"
  type        = string
  default     = "ruo.local."
}

variable "reverse_web_zone" {
  description = "Reverse zona za web segment (172.28.10.0/24)"
  type        = string
  default     = "10.28.172.in-addr.arpa."
}

variable "reverse_data_zone" {
  description = "Reverse zona za data segment (172.28.20.0/24)"
  type        = string
  default     = "20.28.172.in-addr.arpa."
}

variable "ttl" {
  description = "TTL zapisa"
  type        = number
  default     = 300
}

# Adrese moraju odgovarati planu adresiranja iz ansible/group_vars/all.yml
# i app/.env (jedan plan adresiranja, tri mjesta gdje se koristi).
variable "frontend_ip" {
  type    = string
  default = "172.28.10.10"
}

variable "backend_ip" {
  type    = string
  default = "172.28.10.20"
}

variable "db_ip" {
  type    = string
  default = "172.28.20.30"
}
