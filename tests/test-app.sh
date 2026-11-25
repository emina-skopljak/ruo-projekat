#!/usr/bin/env bash
#
# Test aplikacije kroz sva tri sloja (AO-1) + opciono trajnost podataka (AO-10).
#
# Upotreba:
#   BASE_URL=http://192.168.100.10:8080 ./tests/test-app.sh
#   BASE_URL=... PERSISTENCE=yes ./tests/test-app.sh
#
# PERSISTENCE=yes trazi SSH pristup VM-u (VM_IP, SSH_KEY) i kratko obnavlja
# kontejner baze — dokaz da podaci zive u volume-u, ne u kontejneru.

set -euo pipefail

BASE_URL="${BASE_URL:?BASE_URL nije postavljen (npr. http://192.168.100.10:8080)}"
PERSISTENCE="${PERSISTENCE:-no}"
VM_IP="${VM_IP:-192.168.100.10}"
SSH_KEY="${SSH_KEY:-$HOME/.ruo/ssh/id_ruo}"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "  OK: $*"; }

echo "Testiram $BASE_URL"

# --- 1. frontend radi -------------------------------------------------------
body="$(curl -fsS -m 5 "$BASE_URL/healthz")" || fail "frontend ne odgovara na /healthz"
[ "$body" = "ok" ] || fail "neocekivan odgovor na /healthz: $body"
ok "frontend (nginx) odgovara"

# --- 2. backend i baza rade kroz frontend ----------------------------------
notes="$(curl -fsS -m 10 "$BASE_URL/api/notes")" || fail "backend ne vraca /api/notes"
echo "$notes" | grep -q '\[' || fail "odgovor nije JSON lista: $notes"
ok "backend cita iz baze"

# --- 3. upis prolazi kroz sva tri sloja ------------------------------------
marker="test-$(date +%s)-$$"
created="$(curl -fsS -m 10 -X POST "$BASE_URL/api/notes" \
  -H 'Content-Type: application/json' \
  -d "{\"body\":\"$marker\"}")" || fail "upis nije prosao"
echo "$created" | grep -q "$marker" || fail "upisani zapis nije vracen: $created"
ok "upis: $marker"

curl -fsS -m 10 "$BASE_URL/api/notes" | grep -q "$marker" || fail "upisani zapis nije u listi"
ok "zapis se vidi u listi"

# --- 4. imena iz zone, ne IP adrese ----------------------------------------
info="$(curl -fsS -m 10 "$BASE_URL/api/info")" || fail "nema /api/info"
echo "$info" | grep -q '"db_host":"db\.' || fail "backend ne koristi DNS ime za bazu: $info"
ok "backend koristi DNS ime baze ($(echo "$info" | sed -n 's/.*"db_host":"\([^"]*\)".*/\1/p'))"

# --- 5. AO-10: podatak prezivljava ponovno kreiranje kontejnera baze -------
if [ "$PERSISTENCE" = "yes" ]; then
  [ -r "$SSH_KEY" ] || fail "PERSISTENCE=yes trazi SSH kljuc ($SSH_KEY)"

  echo "  ... obnavljam kontejner baze i provjeravam trajnost"
  ssh -i "$SSH_KEY" -o BatchMode=yes -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "ruo@$VM_IP" \
      'cd /opt/ruo/app && docker compose rm -sf db >/dev/null && docker compose up -d db >/dev/null'

  for _ in $(seq 1 30); do
    if curl -fsS -m 5 "$BASE_URL/api/notes" 2>/dev/null | grep -q "$marker"; then
      ok "podatak je prezivio obnovu kontejnera baze (AO-10)"
      break
    fi
    sleep 2
  done

  curl -fsS -m 10 "$BASE_URL/api/notes" | grep -q "$marker" \
    || fail "podatak je nestao nakon obnove kontejnera baze"
fi

echo "SVE PROSLO: aplikacija radi kroz sva tri sloja."
