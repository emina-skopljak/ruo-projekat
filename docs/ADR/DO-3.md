# DO-3: Plan adresiranja

Status: prihvaćeno

## Kontekst

AO-6 traži vlastitu podmrežu po segmentu, a AO-7 i AO-8 traže da se komponente
adresiraju isključivo DNS imenima. DNS zapisi (A) moraju pokazivati na adrese
koje se ne mijenjaju između dva `apply` ciklusa, inače zona i stvarno stanje
razilaze. Treba odlučiti i kako VM dobija svoju adresu.

## Razmotrene opcije

1. DHCP za sve, imena se rješavaju dinamički (Docker i libvirt DHCP).
2. Statičke adrese za sve kontejnere i VM; podmreže po segmentu.
3. Statičke adrese samo za bazu, ostalo DHCP.

## Odluka

Statičke adrese, fiksne podmreže i fiksni plan:

| Segment | Podmreža | Adrese |
|---|---|---|
| upravljanje (VM) | 192.168.100.0/24 | VM `.10`, gateway `.1` |
| web | 172.28.10.0/24 | frontend `.10`, backend `.20`, DNS gateway `.1` |
| data | 172.28.20.0/24 | backend `.20`, baza `.30`, DNS gateway `.1` |

Adresa VM-a se ne dobija DHCP-om, nego je postavljena u cloud-init
`network-config` (netplan), po MAC adresi interfejsa. Kontejneri dobijaju
adrese kroz `ipv4_address` u `compose.yaml`.

## Obrazloženje i posljedice

Opcija 1 je najkraća, ali ruši AO-7: A zapis bi pokazivao na adresu koja se
mijenja pri svakom podizanju. Opcija 3 daje isti problem za frontend i backend,
a prednost (manje ručnog rada) ne postoji jer plan adresiranja ionako mora biti
dokumentovan.

Posljedice: plan adresiranja postoji na tri mjesta — `variables.tf` /
`compose.yaml` / `group_vars/all.yml` — i to je svjesno: Terraform gradi mrežu,
Docker dodjeljuje adrese, a BIND ih objavljuje. Zato su vrijednosti iste i
provjeravaju se testom. Slabost: dodavanje novog kontejnera traži novu adresu i
novi zapis; to je cijena determinizma.
