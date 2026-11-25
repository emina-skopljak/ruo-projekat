# RuO 2026/27 — troslojna aplikacija kao kod

**Student:** Emina Skopljak
**Predmet:** Računarstvo u oblaku, II ciklus, III semestar 2026/27
**Repozitorij:** https://github.com/emina-skopljak/ruo-projekat

Infrastruktura za troslojnu web aplikaciju, opisana isključivo kodom: virtuelna
mašina (Terraform + libvirt), početna konfiguracija (cloud-init), konfiguracija
servera (Ansible), kontejneri (Docker Compose), segmentirana mreža i
autoritativni DNS (BIND + Terraform RFC 2136). Aplikacija je samo povod i nije
predmet ocjenjivanja.

## Arhitektura

```
Windows / WSL2 (host)
  terraform · ansible · virsh · make
      │
      └── libvirt NAT 192.168.100.0/24
            │
            └── VM "ruo-app"  Ubuntu 24.04 · 2 vCPU · 2 GB · 12 GB disk
                  ├── Docker Engine + Compose
                  ├── BIND 9 — autoritativan za ruo.local
                  └── kontejneri
                        web mreža  172.28.10.0/24
                          frontend  172.28.10.10   (objavljen port 80)
                          backend   172.28.10.20
                        data mreža 172.28.20.0/24
                          backend   172.28.20.20
                          baza      172.28.20.30   (bez objavljenog porta)
```

Izolacija je posljedica topologije: frontend nema interfejs u `data` mreži, pa
do baze ne postoji mrežni put; baza nema objavljen port, pa nije dostupna
izvana. Tok zahtjeva je isključivo frontend → backend → baza.

| Ravan | Podmreža | Adrese |
|---|---|---|
| upravljanje | 192.168.100.0/24 | VM `.10`, gateway `.1` |
| web | 172.28.10.0/24 | frontend `.10`, backend `.20` |
| data | 172.28.20.0/24 | backend `.20`, baza `.30` |

Sve adrese su statičke (DO-3): VM dobija adresu iz cloud-init `network-config`,
kontejneri iz `ipv4_address` u `compose.yaml`.

## Struktura repozitorija

```
app/            frontend (nginx), backend (FastAPI), db/init.sql, compose.yaml
terraform/vm/   mreža, diskovi, cloud-init seed, domena
terraform/dns/  A i PTR zapisi (provider hashicorp/dns, RFC 2136 + TSIG)
cloud-init/     user-data, meta-data, network-config (šabloni)
ansible/        site.yml; role common, docker, dns, app; group_vars
tests/          test-app.sh, test-isolation.sh, test-dns.sh
scripts/        gen-secrets.sh, gen-inventory.sh, wait-ssh.sh, drift-demo.sh
docs/ADR/       DO-1 … DO-9
Makefile
```

## Preduslovi

WSL2 Ubuntu 24.04 (ili Linux) sa: `terraform`, `ansible-core`, `qemu-system-x86`,
`libvirt-daemon-system`, `virtinst`, `cloud-image-utils`, `genisoimage`, `make`,
`bind9-dnsutils`, `netcat-openbsd`, `jq`, `git`.

- VM koristi KVM (`/dev/kvm`), a podržan je i rad bez KVM-a (QEMU TCG, sporije).
- Ubuntu cloud slika se preuzima jednom:
  `~/.cache/ruo/noble-server-cloudimg-amd64.img`
- libvirt mora biti dostupan: `virsh -c qemu:///system list` bez greške.

## Pokretanje od praznog sistema

```bash
make check      # alati, libvirt, cloud slika
make secrets    # SSH kljuc, lozinka baze, TSIG secret -> ~/.ruo (van Gita)
make all        # infra -> config -> dns -> deploy
make test       # aplikacija, izolacija, DNS
make test PERSISTENCE=yes   # AO-10: podatak prezivljava recreate baze
make drift      # AO-8: rucna izmjena zapisa, plan, ispravka
make destroy    # uklanjanje svega
```

Sirove komande bez `make` (isti redoslijed):

```bash
terraform -chdir=terraform/vm init && terraform -chdir=terraform/vm apply
bash scripts/gen-inventory.sh && bash scripts/wait-ssh.sh 192.168.100.10 ruo ~/.ruo/ssh/id_ruo
cd ansible && ansible-playbook site.yml --tags common,docker,dns
cd .. && TF_VAR_tsig_secret="$(cat ~/.ruo/tsig.key)" \
  terraform -chdir=terraform/dns apply -var="dns_server=192.168.100.10" -var="zone=ruo.local."
cd ansible && ansible-playbook site.yml --tags app
```

Aplikacija je dostupna na `http://192.168.100.10:8080`
(iz Windowsa kroz tunel: `./scripts/app-tunnel.sh` → `http://localhost:8090`).

## Dokazi

**AO-3 — infrastruktura kao kod.** Parametri su varijable, adrese outputi, state
nije u Gitu.

```
$ terraform -chdir=terraform/vm plan
No changes. Your infrastructure matches the configuration.
```

**AO-4 — cloud-init.** Korisnik `ruo` i SSH ključ; prijava lozinkom odbijena.

```
$ ssh ruo@192.168.100.10 'hostname -f; ip -br a show eth0; cloud-init status'
ruo-app.ruo.local
eth0  UP  192.168.100.10/24
status: done

$ ssh -o PubkeyAuthentication=no ruo@192.168.100.10
ruo@192.168.100.10: Permission denied (publickey).
```

**AO-5 — idempotentnost.** Drugo izvršavanje ne mijenja stanje.

```
$ ansible-playbook site.yml --tags dns
PLAY RECAP
ruo-app : ok=16  changed=0  unreachable=0  failed=0
```

**AO-7 / AO-8 — DNS.** Zona je autoritativna, zapisi su Terraform resursi.

```
$ dig @192.168.100.10 SOA ruo.local +short
ns.ruo.local. hostmaster.ruo.local. 2026112401 3600 900 604800 300

$ dig @192.168.100.10 web.ruo.local +short
172.28.10.10
```

Drift: zapis `web` je ručno promijenjen na `10.99.99.99` preko `nsupdate`,
`terraform plan` je prijavio razliku, `apply` je vratio `172.28.10.10`, a
kontrolni plan je bio čist.

**AO-6 — izolacija.** `make test` pokreće `tests/test-isolation.sh`: iz
kontejnera frontenda `nc -z db.ruo.local 5432` ne prolazi, frontend vidi backend,
baza nema objavljen port i nije na `web` mreži.

**AO-10 — trajnost.** `make test PERSISTENCE=yes` upiše zapis, obriše kontejner
baze i potvrdi da zapis ostaje (podatak je u volume-u `db_data`).

## Tajne

U Git ne idu: `.env`, `*.tfstate`, `.terraform/`, privatni i TSIG ključevi.
Tajne se generišu pri prvom pokretanju u `~/.ruo` (direktoriji `700`, fajlovi
`600`): SSH ključ, lozinka baze, TSIG secret, vault lozinka. `gen-secrets.sh` je
idempotentan i ne prepisuje postojeće. Vidi ADR DO-9.

## Napomene

- Repozitorij mora biti dostupan asistentu (javni ili dijeljeni).
- `ruo.local` pripada mDNS domenu; u ovom okruženju upiti idu direktno na BIND,
  pa ne smeta (vidi ADR DO-8).
- Round-robin DNS nije aktiviran jer postoji jedna instanca backenda; zona je
  spremna za drugi A zapis.
- `make destroy` uklanja VM, mrežu i DNS zapise; pool `default` (u koji provider
  smješta cloud-init seed) može ostati definisan — to je nuspojava libvirt
  providera, opisana u ADR-u DO-2.
