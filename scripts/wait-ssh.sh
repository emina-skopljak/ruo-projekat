#!/usr/bin/env bash
#
# Sacekaj da VM podigne SSH. Koristi se poslije `terraform apply` jer
# Terraform ne ceka da cloud-init zavrsi (a i ne treba: cekanje nije stanje
# infrastrukture, nego provjera spremnosti).
#
# Upotreba: ./scripts/wait-ssh.sh <ip> <korisnik> <privatni_kljuc> [timeout_s]

set -euo pipefail

IP="${1:?ip}"
USER_NAME="${2:?korisnik}"
KEY="${3:?privatni kljuc}"
TIMEOUT="${4:-240}"

echo "Cekam SSH na ${USER_NAME}@${IP} (najvise ${TIMEOUT}s)..."

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  if ssh -i "$KEY" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ConnectTimeout=3 \
        "${USER_NAME}@${IP}" true 2>/dev/null; then
    echo "SSH je dostupan nakon ~${elapsed}s."
    exit 0
  fi
  sleep 3
  elapsed=$((elapsed + 3))
  if [ $((elapsed % 30)) -eq 0 ]; then
    echo "  ... jos cekam (${elapsed}s)"
  fi
done

echo "GRESKA: SSH nije dostupan nakon ${TIMEOUT}s." >&2
echo "Provjeri: virsh -c qemu:///system list --all" >&2
echo "Konzola:  virsh -c qemu:///system console ruo-app" >&2
exit 1
