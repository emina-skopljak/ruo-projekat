# DO-1: Aplikacija i tehnologije po sloju

Status: prihvaćeno

## Kontekst

AO-1 traži troslojnu aplikaciju: frontend, backend i baza, svaki u svom
kontejneru, s tokom zahtjeva isključivo frontend → backend → baza. Aplikacija
se ne boduje, pa svaka njena složenost troši vrijeme koje nedostaje
infrastrukturi (Terraform, Ansible, BIND, testovi).

## Razmotrene opcije

1. Statički frontend (HTML/JS) + nginx, backend Python/FastAPI, PostgreSQL.
2. React (Vite) + Node/Express + PostgreSQL.
3. Java/Spring Boot + PostgreSQL.
4. Gotova open-source aplikacija (npr. WordPress + MySQL).

## Odluka

Opcija 1: statički frontend koji servira nginx i prosljeđuje `/api` na backend,
backend u FastAPI-ju (četiri rute), baza PostgreSQL 16.

## Obrazloženje i posljedice

Tri stvarno odvojena procesa, bez ramena u kojem se spajaju (za razliku od
WordPressa i Next.js-a, koji imaju dva sloja i kršili bi AO-1). Frontend nema
stanje, backend nema stanje, baza je jedini stateful dio — zato je AO-10
(perzistencija) provjerljiv u trideset sekundi, a backend se kasnije može
umnožiti bez izmjena u kodu.

Posljedice: nema korisničkih naloga, sesija ni uploada, pa nema ni dodatnih
odluka o njima. Slabost: aplikacija je minimalna i to se vidi; prednost je što
se svaka linija može objasniti na odbrani, a složenost je namjerno prebačena
na infrastrukturu, koja se boduje.
