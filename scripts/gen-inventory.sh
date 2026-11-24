#!/usr/bin/env bash
#
# DO-6: Ansible inventory se GENERISE iz Terraform output-a.
# Nema rucnog prepisivanja IP adrese: ako se parametri VM-a promijene,
# inventory se regenerise jednom komandom i uvijek je tacan.
#
# Upotreba: ./scripts/gen-inventory.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/terraform/vm"
INVENTORY="$ROOT/ansible/inventory.ini"

if ! command -v jq >/dev/null 2>&1; then
  echo "GRESKA: jq nije instaliran (sudo apt install -y jq)" >&2
  exit 1
fi

outputs="$(terraform -chdir="$TF_DIR" output -json 2>/dev/null)" || {
  echo "GRESKA: 'terraform output' ne radi. Je li 'terraform apply' izvrsen?" >&2
  exit 1
}

vm_ip="$(jq -r '.vm_ip.value' <<<"$outputs")"
admin_user="$(jq -r '.admin_user.value' <<<"$outputs")"
vm_name="$(jq -r '.vm_name.value' <<<"$outputs")"

if [ -z "$vm_ip" ] || [ "$vm_ip" = "null" ]; then
  echo "GRESKA: output 'vm_ip' je prazan — infrastruktura nije podignuta." >&2
  exit 1
fi

cat > "$INVENTORY" <<EOF
# GENERISANO iz 'terraform output' (DO-6). Ne uredjuj rucno.
# Regenerisi sa: ./scripts/gen-inventory.sh

[app]
${vm_name} ansible_host=${vm_ip} ansible_user=${admin_user}

[app:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo "Inventory zapisan: ${INVENTORY}"
grep -v '^\s*#' "$INVENTORY" | grep -v '^\s*$'
