# DO-7: Organizacija Ansible rola i varijabli

Status: prihvaćeno

## Kontekst

AO-5 traži da konfiguraciju servera radi Ansible organizovan u role i da
playbook bude idempotentan. Treba odlučiti kako se role dijele i gdje žive
varijable, jer od toga zavisi da li se promjena radi na jednom mjestu ili na
pet.

## Razmotrene opcije

1. Role po komponenti (frontend, backend, baza) — jedna rola po kontejneru.
2. Role po funkciji infrastrukture: `common`, `docker`, `dns`, `app`.
3. Jedna velika rola sa više task fajlova i `include_tasks`.

## Odluka

Opcija 2, uz jasnu podjelu varijabli:

- `roles/<rola>/defaults` — ono što je interno roli (lista paketa, putanje,
  imena servisa) i ne treba se mijenjati izvana;
- `group_vars/all.yml` — projektno: zona, TTL, plan adresiranja, port;
- krajnji korisnik mijenja samo `group_vars`, nikad `defaults`.

## Obrazloženje i posljedice

Role po aplikativnoj komponenti bi podrazumijevale da svaka rola instalira
Docker ili dira isti servis — isti task bi se pojavio više puta. Podjela po
funkciji prati slojeve infrastrukture i omogućava pokretanje po tagovima
(`--tags docker`, `--tags dns`), što je i korišteno pri izradi.

Posljedice: izmjena plana adresiranja je na jednom mjestu (`group_vars`), a
izmjena interne logike role ne dira projektne varijable. Slabost: `app` rola
zavisi od `docker` role (redoslijed u `site.yml`), pa se ne može pokrenuti
samostalno na praznoj VM — to je dokumentovano redoslijedom u `site.yml`.
