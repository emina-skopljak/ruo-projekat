#!/usr/bin/env bash
#
# AO-9: tajne se generisu pri prvom pokretanju i nikad ne ulaze u Git.
# Sve sto ovaj skript napravi zivi u $HOME/.ruo (izvan repozitorija).
#
# Skript je idempotentan: ako fajl vec postoji, NE prepisuje ga. Tako se
# lozinka baze ne mijenja slucajno pri ponovnom pokretanju.
#
# Sadrzaj:
#   ~/.ruo/ssh/id_ruo(.pub)   upravljacki SSH kljuc (AO-4)
#   ~/.ruo/vault-pass         lozinka za ansible-vault (AO-9)
#   ~/.ruo/db-password        lozinka korisnika baze
#   ~/.ruo/tsig.key           TSIG secret za RFC 2136 (AO-8)

set -euo pipefail

SECRETS_DIR="${RUO_SECRETS_DIR:-$HOME/.ruo}"

umask 077
mkdir -p "$SECRETS_DIR/ssh"
chmod 700 "$SECRETS_DIR" "$SECRETS_DIR/ssh"

created=0

if [ ! -f "$SECRETS_DIR/ssh/id_ruo" ]; then
  ssh-keygen -q -t ed25519 -N "" -C "ruo-admin" -f "$SECRETS_DIR/ssh/id_ruo"
  echo "  + SSH kljuc:      $SECRETS_DIR/ssh/id_ruo"
  created=1
fi

if [ ! -f "$SECRETS_DIR/vault-pass" ]; then
  openssl rand -base64 32 > "$SECRETS_DIR/vault-pass"
  echo "  + vault lozinka:  $SECRETS_DIR/vault-pass"
  created=1
fi

if [ ! -f "$SECRETS_DIR/db-password" ]; then
  openssl rand -hex 24 > "$SECRETS_DIR/db-password"
  echo "  + DB lozinka:     $SECRETS_DIR/db-password"
  created=1
fi

if [ ! -f "$SECRETS_DIR/tsig.key" ]; then
  openssl rand -base64 32 | tr -d '\n' > "$SECRETS_DIR/tsig.key"
  echo "  + TSIG secret:    $SECRETS_DIR/tsig.key"
  created=1
fi

# Dozvole: direktoriji 700 (samo vlasnik ulazi), fajlovi 600 (samo vlasnik cita).
# NAMJERNO ne koristimo `chmod 600 "$SECRETS_DIR"/*` jer bi to skinulo x-bit
# sa poddirektorija ssh/ i time onemogucilo citanje kljuca unutra.
find "$SECRETS_DIR" -type d -exec chmod 700 {} + 2>/dev/null || true
find "$SECRETS_DIR" -type f -exec chmod 600 {} + 2>/dev/null || true

if [ "$created" -eq 0 ]; then
  echo "Sve tajne vec postoje u $SECRETS_DIR — nista nije mijenjano."
else
  echo "Tajne su spremne u $SECRETS_DIR (izvan repozitorija)."
fi
