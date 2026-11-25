SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Putanje i parametri (sve se moze pregaziti: make deploy SECRETS=...)
# ---------------------------------------------------------------------------
SECRETS     ?= $(HOME)/.ruo
VM_DIR      := terraform/vm
DNS_DIR     := terraform/dns
PERSISTENCE ?= no
ZONE        ?= ruo.local
APP_PORT    ?= 8080

# ---------------------------------------------------------------------------
.PHONY: help check secrets infra plan config dns dns-plan deploy test drift all destroy

help:
	@printf '%s\n' \
	  '' \
	  '  make check      provjeri alate, libvirt i cloud sliku' \
	  '  make secrets    generisi tajne u ~/.ruo (SSH kljuc, TSIG, lozinka baze)' \
	  '  make infra      Terraform: VM, mreza, diskovi, cloud-init' \
	  '  make plan       Terraform plan za VM (bez primjene)' \
	  '  make config     inventory iz TF outputa + Ansible (common, docker, dns)' \
	  '  make dns        Terraform: DNS zapisi preko RFC 2136' \
	  '  make dns-plan   plan DNS zapisa bez primjene' \
	  '  make deploy     Ansible: isporuka i pokretanje aplikacije na VM-u' \
	  '  make test       testovi: aplikacija, izolacija, DNS (PERSISTENCE=yes za trajnost)' \
	  '  make drift      demonstracija DNS drifta i Terraform ispravke' \
	  '  make all        infra -> config -> dns -> deploy' \
	  '  make destroy    ukloni DNS zapise, VM, mrezu i diskove' \
	  ''

# ---------------------------------------------------------------------------
check:
	@missing=0; \
	for t in terraform ansible-playbook virsh jq dig nsupdate ssh make python3; do \
	  command -v "$$t" >/dev/null 2>&1 || { echo "NEDOSTAJE: $$t" >&2; missing=1; }; \
	done; \
	[ "$$missing" -eq 0 ] || exit 1; \
	virsh -c qemu:///system list --all >/dev/null 2>&1 || { \
	  echo "GRESKA: libvirt nije dostupan (sudo systemctl start libvirtd)" >&2; exit 1; }; \
	test -r "$$HOME/.cache/ruo/noble-server-cloudimg-amd64.img" || { \
	  echo "GRESKA: nema cloud slike u ~/.cache/ruo/" >&2; exit 1; }; \
	echo "OK: alati, libvirt i cloud slika."

secrets:
	@RUO_SECRETS_DIR="$(SECRETS)" bash scripts/gen-secrets.sh

# --- infrastruktura --------------------------------------------------------
infra:
	@$(MAKE) --no-print-directory secrets
	@terraform -chdir=$(VM_DIR) init -input=false
	@terraform -chdir=$(VM_DIR) apply -input=false -auto-approve

plan:
	@terraform -chdir=$(VM_DIR) plan -input=false

# --- konfiguracija ---------------------------------------------------------
config:
	@bash scripts/gen-inventory.sh
	@set -euo pipefail; \
	ip="$$(terraform -chdir=$(VM_DIR) output -raw vm_ip)"; \
	user="$$(terraform -chdir=$(VM_DIR) output -raw admin_user)"; \
	bash scripts/wait-ssh.sh "$$ip" "$$user" "$(SECRETS)/ssh/id_ruo"
	@cd ansible && ansible-playbook site.yml --tags common,docker,dns

# --- DNS zapisi ------------------------------------------------------------
dns:
	@set -euo pipefail; \
	ip="$$(terraform -chdir=$(VM_DIR) output -raw vm_ip)"; \
	terraform -chdir=$(DNS_DIR) init -input=false; \
	TF_VAR_tsig_secret="$$(cat $(SECRETS)/tsig.key)" \
	  terraform -chdir=$(DNS_DIR) apply -input=false -auto-approve \
	    -var="dns_server=$$ip" -var="zone=$(ZONE)."

dns-plan:
	@set -euo pipefail; \
	ip="$$(terraform -chdir=$(VM_DIR) output -raw vm_ip)"; \
	terraform -chdir=$(DNS_DIR) init -input=false; \
	TF_VAR_tsig_secret="$$(cat $(SECRETS)/tsig.key)" \
	  terraform -chdir=$(DNS_DIR) plan -input=false \
	    -var="dns_server=$$ip" -var="zone=$(ZONE)."

# --- aplikacija ------------------------------------------------------------
deploy:
	@bash scripts/gen-inventory.sh
	@cd ansible && ansible-playbook site.yml --tags app

# --- testovi ---------------------------------------------------------------
test:
	@set -euo pipefail; \
	ip="$$(terraform -chdir=$(VM_DIR) output -raw vm_ip)"; \
	echo "== aplikacija =="; \
	BASE_URL="http://$$ip:$(APP_PORT)" PERSISTENCE="$(PERSISTENCE)" \
	  VM_IP="$$ip" SSH_KEY="$(SECRETS)/ssh/id_ruo" bash tests/test-app.sh; \
	echo "== izolacija =="; \
	VM_IP="$$ip" SSH_KEY="$(SECRETS)/ssh/id_ruo" bash tests/test-isolation.sh; \
	echo "== dns =="; \
	VM_IP="$$ip" ZONE="$(ZONE)" SSH_KEY="$(SECRETS)/ssh/id_ruo" bash tests/test-dns.sh

drift:
	@set -euo pipefail; \
	ip="$$(terraform -chdir=$(VM_DIR) output -raw vm_ip)"; \
	bash scripts/drift-demo.sh "$$ip" "$(SECRETS)/tsig.key" "$(ZONE)"

# --- ciklus za odbranu -----------------------------------------------------
all:
	@$(MAKE) --no-print-directory infra
	@$(MAKE) --no-print-directory config
	@$(MAKE) --no-print-directory dns
	@$(MAKE) --no-print-directory deploy

destroy:
	@set -euo pipefail; \
	if [ -s "$(DNS_DIR)/terraform.tfstate" ]; then \
	  ip="$$(terraform -chdir=$(VM_DIR) output -raw vm_ip)"; \
	  TF_VAR_tsig_secret="$$(cat $(SECRETS)/tsig.key)" \
	    terraform -chdir=$(DNS_DIR) destroy -input=false -auto-approve \
	      -var="dns_server=$$ip" -var="zone=$(ZONE)." || true; \
	fi; \
	terraform -chdir=$(VM_DIR) destroy -input=false -auto-approve; \
	rm -f ansible/inventory.ini; \
	echo "Uklonjeno. Tajne u $(SECRETS) su ostale (namjerno)."
