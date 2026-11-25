# DO-9: Upravljanje tajnama

Status: prihvaćeno

## Kontekst

AO-9 traži da lozinke baze, TSIG ključ i privatni ključevi nikad nisu u Gitu u
čistom obliku, nego da se šifruju `ansible-vault`-om ili generišu pri pokretanju.
Tajna koja jednom uđe u historiju smatra se otkrivenom. Istovremeno, ciklus
`destroy → all` mora raditi bez ijednog ručnog koraka (AO-2).

## Razmotrene opcije

1. Tajne u `ansible-vault` fajlu koji je u Gitu (šifrovan), vault lozinka van
   repozitorija.
2. Tajne se generišu pri prvom pokretanju u `~/.ruo` (openssl/ssh-keygen) i
   nikad ne ulaze u Git.
3. Tajne u CI/CD tajnama (nema CI-ja u projektu).

## Odluka

Opcija 2, sa sljedećim sadržajem `~/.ruo` (700, fajlovi 600):

| Tajna | Fajl | Kako nastaje | Ko je koristi |
|---|---|---|---|
| SSH ključ za upravljanje | `ssh/id_ruo(.pub)` | `ssh-keygen` | cloud-init (javni), Ansible (privatni) |
| lozinka baze | `db-password` | `openssl rand -hex 24` | Ansible → `.env` na VM-u |
| TSIG secret | `tsig.key` | `openssl rand -base64 32` | Ansible (BIND), Terraform (RFC 2136) |
| vault lozinka | `vault-pass` | `openssl rand -base64 32` | rezervisano za `ansible-vault` |

Skripta `scripts/gen-secrets.sh` je idempotentna: postojeće tajne ne prepisuje,
pa se lozinka baze ne mijenja slučajno pri ponovnom pokretanju.

## Obrazloženje i posljedice

Vault fajl u Gitu je legitimna opcija, ali uvodi tajnu koja je šifrovana i
zauvijek ostaje u historiji; ako vault lozinka procuri, procurila je i cijela
historija. Generisanje pri pokretanju je jednostavnije i ne ostavlja nišifrovan
ni šifrovan materijal u repozitoriju.

Posljedice: tajne su vezane za računar (nema ih u repou), pa `make destroy`
namjerno ne briše `~/.ruo` — time ponovni `make all` ne mijenja lozinku baze i
volume ostaje iskoristiv. Terraform state sadrži TSIG secret, ali state je
lokalno i u `.gitignore`. Slabost: nema centralnog upravljanja ni rotacije;
u produkciji bi to bio Vault ili cloud secret manager, a ključevi bi se
rotirali po rasporedu.
