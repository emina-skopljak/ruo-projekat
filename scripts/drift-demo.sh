#!/usr/bin/env bash
#
# Demonstracija DNS drifta i Terraform ispravke (AO-8).
#
# Tok:
#   1. zapis web.ruo.local se rucno promijeni na pogresnu adresu (nsupdate)
#   2. terraform plan pokaze razliku izmedju stvarnog i zeljenog stanja
#   3. terraform apply vrati zeljeno stanje
#   4. dig potvrdi da je zapis vracen
#
# Upotreba: ./scripts/drift-demo.sh [vm_ip] [tsig_key] [zona]

set -euo pipefail

VM_IP="${1:-192.168.100.10}"
TSIG_KEY="${2:-$HOME/.ruo/tsig.key}"
ZONE="${3:-ruo.local}"
RECORD="web.$ZONE."
WRONG_IP="10.99.99.99"

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { printf '\n== %s ==\n' "$*"; }

[ -r "$TSIG_KEY" ] || fail "nema TSIG kljuca: $TSIG_KEY"

# Provider trazi kljuc i za plan (konfiguracija providera), ne samo za apply.
export TF_VAR_tsig_secret="$(cat "$TSIG_KEY")"

orig="$(dig +short "$RECORD" "@$VM_IP" | head -1)"
[ -n "$orig" ] || fail "zapis $RECORD ne postoji u zoni"
echo "Pocetno stanje: $RECORD -> $orig"

step "1. Rucna izmjena mimo koda (nsupdate, kao da je neko dirao zonu)"
nsupdate -y "hmac-sha256:ruo-key:$(cat "$TSIG_KEY")" <<EOF
server $VM_IP
zone $ZONE
update delete $RECORD A
update add $RECORD 300 A $WRONG_IP
send
EOF
sleep 1

now="$(dig +short "$RECORD" "@$VM_IP" | head -1)"
echo "Nakon rucne izmjene: $RECORD -> $now"
[ "$now" = "$WRONG_IP" ] || fail "rucna izmjena nije primijenjena (dobijeno: $now)"

step "2. terraform plan detektuje drift (ocekivan je exit code 2)"
set +e
terraform -chdir=terraform/dns plan -input=false \
  -var="dns_server=$VM_IP" -var="zone=$ZONE." \
  -detailed-exitcode >/tmp/ruo-drift-plan.txt 2>&1
rc=$?
set -e

case "$rc" in
  0) fail "Terraform NE vidi drift iako je zapis promijenjen" ;;
  2) echo "Drift detektovan (plan predlaze vracanje na $orig):"
     grep -E 'A record|addresses|must be replaced|~ update' /tmp/ruo-drift-plan.txt | head -10 || true
     ;;
  *) echo "terraform plan je pao (rc=$rc):"; tail -20 /tmp/ruo-drift-plan.txt; exit 1 ;;
esac

step "3. terraform apply vraca zeljeno stanje"
TF_VAR_tsig_secret="$(cat "$TSIG_KEY")" terraform -chdir=terraform/dns apply \
  -input=false -auto-approve -var="dns_server=$VM_IP" -var="zone=$ZONE." >/dev/null

sleep 1
final="$(dig +short "$RECORD" "@$VM_IP" | head -1)"
echo "Nakon apply: $RECORD -> $final"
[ "$final" = "$orig" ] || fail "zapis nije vracen (dobijeno: $final, ocekivano: $orig)"

step "4. Kontrolni plan mora biti cist"
terraform -chdir=terraform/dns plan -input=false \
  -var="dns_server=$VM_IP" -var="zone=$ZONE." >/tmp/ruo-drift-plan2.txt 2>&1
grep -q 'No changes' /tmp/ruo-drift-plan2.txt || fail "plan nije cist nakon apply"
echo "No changes."

echo
echo "SVE PROSLO: drift je detektovan i ispravljen iskljucivo kroz kod."
