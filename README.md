# RuO 2026/27 — troslojna aplikacija kao kod

Projektni zadatak iz predmeta **Računarstvo u oblaku** (Politehnički fakultet Zenica).
Cilj projekta je infrastruktura opisana kodom: virtuelne mašine, konfiguracija,
kontejneri, segmentirana mreža i autoritativni DNS. Aplikacija je samo povod i
**nije predmet ocjenjivanja**.

> **Status:** u izradi. Trenutno je gotov prvi sloj — aplikacija i njena
> kontejnerizacija. Infrastruktura (Terraform, cloud-init, Ansible, BIND) slijedi.

## Aplikacija

Mini evidencija zadataka. Tok zahtjeva je isključivo **frontend → backend → baza** (AO-1):

| Sloj | Tehnologija | Kontejner |
|---|---|---|
| frontend | statički HTML/JS + nginx (reverse proxy na `/api`) | `ruo-app-frontend-1` |
| backend | Python 3.12 + FastAPI, `GET/POST /api/notes` | `ruo-app-backend-1` |
| baza | PostgreSQL 16 + named volume | `ruo-app-db-1` |

### Struktura

```
app/
├── frontend/      index.html, app.js, nginx.conf.template, Dockerfile
├── backend/       main.py, requirements.txt, Dockerfile (multi-stage)
├── db/            init.sql
├── compose.yaml   3 servisa, 2 mreže, 1 volume
└── .env.example   primjer konfiguracije (stvarni .env nije u Gitu)
```

### Mrežna topologija (AO-6)

```
            internet
               │  samo port frontenda
        ┌──────▼───────┐
        │   frontend   │   web mreža: 172.28.10.0/24
        └──────┬───────┘
               │ /api
        ┌──────▼───────┐
        │   backend    │   web + data mreža
        └──────┬───────┘
               │ SQL
        ┌──────▼───────┐
        │     baza     │   data mreža: 172.28.20.0/24, bez objavljenog porta
        └──────────────┘
```

Frontend je priključen **samo** na `web`, baza **samo** na `data`. Između njih ne
postoji mrežni put — to je ono što provjerava test izolacije.

## Pokretanje (samo aplikacija, bez infrastrukture)

Potrebno: Docker + Docker Compose.

```bash
cd app
cp .env.example .env      # lozinku po želji promijeni
docker compose up -d --build
```

Otvori <http://localhost:8080>.

> Ako je port 8080 zauzet, promijeni `FRONTEND_PORT` u `app/.env` (npr. na 8099);
> port nije hardkodiran, što je i uslov da isto radi na različitim računarima.

Provjere:

```bash
# backend i baza zdraví?
curl -s http://localhost:8080/healthz
docker compose ps

# upis i citanje kroz sva tri sloja
curl -s -X POST http://localhost:8080/api/notes \
     -H 'Content-Type: application/json' -d '{"body":"test"}'
curl -s http://localhost:8080/api/notes

# AO-10: podatak prezivljava ponovno kreiranje kontejnera baze
docker compose rm -sf db && docker compose up -d db
curl -s http://localhost:8080/api/notes

# AO-6: frontend ne smije imati put do baze (mora pasti)
docker compose exec frontend sh -c 'nc -z -w 3 <DB_IP> 5432 && echo "GRESKA: put postoji" || echo "OK: nema puta"'

# zaustavljanje (volume ostaje)
docker compose down
```

## Sljedeći koraci

1. `terraform/vm` — VM i mreže (AO-3), parametri kao varijable, adrese kao outputi
2. `cloud-init/` — korisnik za upravljanje i SSH ključ (AO-4)
3. `ansible/` — role `docker`, `app`, `dns` (AO-5, AO-7)
4. `terraform/dns` — DNS zapisi kao resursi, TSIG (AO-8)
5. `tests/` — izolacija, `dig` upiti, provjera aplikacije
6. `Makefile` — `check`, `infra`, `config`, `dns`, `deploy`, `test`, `all`, `destroy`
7. README dopunjen stvarnim izlazima (plan, `changed=0`, `dig`, testovi)

## Tajne

U Git ne idu: `.env`, `*.tfstate`, `.terraform/`, privatni i TSIG ključevi,
`vault.yml`. U repozitoriju je samo `.env.example`. Vidi ADR DO-9.
