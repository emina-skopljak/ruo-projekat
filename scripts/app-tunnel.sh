#!/usr/bin/env bash
#
# Otvara tunel sa Windows/WSL localhost-a do frontenda u VM-u.
#
# Zasto: frontend je objavljen na VM-u (192.168.100.10:8080), ali Windows ne
# vidi mrezu 192.168.100.0/24. SSH tunel to rjesava bez ikakvih admin prava
# i bez objavljivanja VM-a na mrezu.
#
# Upotreba:  ./scripts/app-tunnel.sh [vm_ip] [lokalni_port]
# Ostavi terminal otvoren; za prekid Ctrl+C.

set -euo pipefail

VM_IP="${1:-192.168.100.10}"
LOCAL_PORT="${2:-8090}"
KEY="${HOME}/.ruo/ssh/id_ruo"

if [ ! -f "$KEY" ]; then
  echo "GRESKA: kljuc $KEY ne postoji (pokreni ./scripts/gen-secrets.sh)" >&2
  exit 1
fi

echo "Tunel: http://localhost:${LOCAL_PORT}  ->  ${VM_IP}:8080"
echo "Otvori tu adresu u browseru. Prekid: Ctrl+C"
echo

exec ssh -N \
  -i "$KEY" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  -o ExitOnForwardFailure=yes \
  -L "127.0.0.1:${LOCAL_PORT}:127.0.0.1:8080" \
  "ruo@${VM_IP}"
