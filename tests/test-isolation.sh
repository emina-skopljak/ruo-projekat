#!/usr/bin/env bash
#
# Test mrezne izolacije (AO-6). Provjere se izvode NA VM-u, u kontejnerima.
#
# Ocekivani rezultat:
#   - frontend -> baza (5432)            MORA pasti
#   - frontend -> backend (8000)         MORA raditi
#   - baza nema objavljen port na hostu
#   - baza ne izlazi na internet (ako je data mreza internal)
#
# Upotreba: VM_IP=192.168.100.10 SSH_KEY=~/.ruo/ssh/id_ruo ./tests/test-isolation.sh

set -euo pipefail

VM_IP="${VM_IP:-192.168.100.10}"
SSH_KEY="${SSH_KEY:-$HOME/.ruo/ssh/id_ruo}"
APP_DIR="${APP_DIR:-/opt/ruo/app}"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "  OK: $*"; }

ssh_vm() {
  ssh -i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "ruo@$VM_IP" "$@"
}

echo "Testiram izolaciju na $VM_IP"

# --- 1. frontend NE SMIJE doci do baze -------------------------------------
out="$(ssh_vm "cd $APP_DIR && docker compose exec -T frontend sh -c 'nc -z -w 3 db.ruo.local 5432 && echo DOSTUPNO || echo BLOKIRANO'")"
case "$out" in
  *BLOKIRANO*) ok "frontend nema put do baze (ocekivano)" ;;
  *DOSTUPNO*)  fail "IZOLACIJA PUKLA: frontend vidi bazu na 5432" ;;
  *)           fail "neocekivan izlaz testa izolacije: $out" ;;
esac

# --- 2. frontend SMIJE doci do backenda ------------------------------------
out="$(ssh_vm "cd $APP_DIR && docker compose exec -T frontend sh -c 'nc -z -w 3 api.ruo.local 8000 && echo DOSTUPNO || echo BLOKIRANO'")"
case "$out" in
  *DOSTUPNO*) ok "frontend vidi backend (ocekivano)" ;;
  *)          fail "frontend ne vidi backend: $out" ;;
esac

# --- 3. baza nema objavljen port na VM-u -----------------------------------
listeners="$(ssh_vm "ss -ltn 2>/dev/null | grep -c ':5432' || true")"
[ "$listeners" = "0" ] || fail "baza objavljuje port 5432 na VM-u (nadeno $listeners listenera)"
ok "baza nema objavljen port (5432 nije na hostu)"

ports="$(ssh_vm "cd $APP_DIR && docker compose ps --format '{{.Name}} {{.Ports}}'")"
echo "$ports" | grep -q 'db-1.*0\.0\.0\.0' && fail "db kontejner ima objavljen port: $ports"
ok "samo frontend objavljuje port"

# --- 4. kontejneri su na ocekivanim mrezama -------------------------------
nets="$(ssh_vm "cd $APP_DIR && docker compose ps -q | xargs -r docker inspect -f '{{.Name}} {{range \$k,\$v := .NetworkSettings.Networks}}{{\$k}} {{end}}'")"
echo "$nets" | grep -q 'frontend-1.*_web' || fail "frontend nije na web mrezi: $nets"
echo "$nets" | grep 'frontend-1' | grep -q '_data' && fail "frontend je na data mrezi (ne smije biti): $nets"
echo "$nets" | grep 'db-1' | grep -q '_data' || fail "baza nije na data mrezi: $nets"
echo "$nets" | grep 'db-1' | grep -q '_web' && fail "baza je na web mrezi (ne smije biti): $nets"
ok "mrezna pripadnost kontejnera je ispravna"
echo "$nets" | sed 's/^/     /'

echo "SVE PROSLO: slojevi su mrezno izolovani."
