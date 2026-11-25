# DO-6: Kako Ansible dobija adrese VM-ova

Status: prihvaćeno

## Kontekst

Adresu VM-a određuje Terraform (AO-3: adrese su outputi). Ansible mora znati
tu adresu, korisnika i ključ. Ručno prepisivanje u inventory je izvor greške:
dovoljno je jednom zaboraviti izmjenu i playbook ide na pogrešan stroj.

## Razmotrene opcije

1. Ručni `inventory.ini` koji se održava pored koda.
2. Inventory generisan iz `terraform output -json` (skripta pri svakom pozivu).
3. Dinamički inventory plugin (npr. libvirt plugin).

## Odluka

Opcija 2: `scripts/gen-inventory.sh` čita `terraform output -json` i piše
`ansible/inventory.ini`. Fajl je u `.gitignore` — nije izvor istine, samo
izvedeni artefakt. `make config` i `make deploy` ga regenerišu prije poziva
playbooka.

## Obrazloženje i posljedice

Ručni inventory je najprostiji, ali se razilazi sa stvarnim stanjem čim se
parametar VM-a promijeni (a asistent na odbrani smije tražiti upravo to).
Dinamički plugin uvodi zavisnost i konfiguraciju koja se mora objašnjavati, a
rješava isti problem.

Posljedice: jedan izvor istine je Terraform state; ako state nema, skripta
jasno padne („je li apply izvršen?"), što je bolje od tihe greške. Slabost:
inventory postoji samo lokalno, pa se playbook ne može pokrenuti bez state-a —
za laboratorijski projekat to je prihvatljivo.
