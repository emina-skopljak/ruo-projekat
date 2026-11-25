#!/usr/bin/env bash
#
# Test DNS zone projekta (AO-7). Provjerava da BIND odgovara za zonu i da su
# imena koja aplikacija koristi stvarno u zoni.
#
# Upotreba: VM_IP=192.168.100.10 ZONE=ruo.local ./tests/test-dns.sh

set -euo pipefail

VM_IP="${VM_IP:-192.168.100.10}"
ZONE="${ZONE:-ruo.local}"
SSH_KEY="${SSH_KEY:-$HOME/.ruo/ssh/id_ruo}"
DNS="@${VM_IP}"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "  OK: $*"; }

dig_q() { dig +short +time=3 +tries=2 "$1" "$DNS" 2>/dev/null; }

echo "Testiram zonu $ZONE na $DNS"

# --- 1. zona je autoritativna ---------------------------------------------
soa="$(dig_q "SOA $ZONE")"
[ -n "$soa" ] || fail "nema SOA zapisa za $ZONE"
ok "SOA: $(echo "$soa" | head -1)"

ns="$(dig_q "NS $ZONE")"
[ -n "$ns" ] || fail "nema NS zapisa za $ZONE"
ok "NS: $ns"

flags="$(dig +noall +comments "SOA $ZONE" "$DNS" | grep -o 'flags: [a-z ]*' || true)"
echo "$flags" | grep -q ' aa' || fail "odgovor nije autoritativan (nema 'aa' u flags)"
ok "odgovor je autoritativan (aa)"

# --- 2. servisna imena su u zoni ------------------------------------------
check_a() {
  local name="$1" expected="$2" got
  got="$(dig_q "$name.$ZONE A")"
  [ "$got" = "$expected" ] || fail "$name.$ZONE -> '$got' (ocekivano '$expected')"
  ok "$name.$ZONE = $got"
}
check_a web "172.28.10.10"
check_a api "172.28.10.20"
check_a db  "172.28.20.30"

# --- 3. PTR zapisi ---------------------------------------------------------
check_ptr() {
  local ip="$1" expected="$2" got
  got="$(dig +short +time=3 +tries=2 -x "$ip" "$DNS" 2>/dev/null)"
  [ "$got" = "$expected" ] || fail "PTR $ip -> '$got' (ocekivano '$expected')"
  ok "PTR $ip = $got"
}
check_ptr 172.28.10.10 "web.$ZONE."
check_ptr 172.28.20.30 "db.$ZONE."

# --- 4. VM sam koristi svoju zonu -----------------------------------------
resolved="$(ssh -i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "ruo@$VM_IP" \
  "getent hosts api.$ZONE | awk '{print \$1}'" 2>/dev/null || true)"
[ "$resolved" = "172.28.10.20" ] || fail "VM ne rjesava api.$ZONE preko svoje zone ('$resolved')"
ok "VM rjesava api.$ZONE preko vlastitog BIND-a"

# --- 5. nema IP adresa u kodu aplikacije ----------------------------------
if command -v grep >/dev/null; then
  if grep -rEn '([0-9]{1,3}\.){3}[0-9]{1,3}' app/backend/main.py app/frontend/app.js app/compose.yaml 2>/dev/null \
     | grep -vE '127\.0\.0\.1|0\.0\.0\.0|172\.28\.|172\.29\.|subnet|ipv4_address' >/dev/null; then
    fail "u kodu aplikacije ima IP adresa (AO-7 trazi imena)"
  fi
  ok "u kodu aplikacije nema IP adresa (samo plan adresiranja u compose-u)"
fi

echo "SVE PROSLO: DNS zona je ispravna."
