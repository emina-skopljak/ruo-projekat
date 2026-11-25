# DO-2: Broj virtuelnih mašina i raspored komponenti

Status: prihvaćeno

## Kontekst

AO-6 traži da svaki sloj bude u svom segmentu s vlastitom podmrežom, da izvana
bude dostupan samo frontend i da frontend nema mrežni put do baze. Način
izvedbe segmenata i broj VM-ova nisu propisani — bira ih student (DO-2).
Host na kojem se brani ima oko 10 GB RAM-a i radi pod nested virtualizacijom.

## Razmotrene opcije

1. Jedna VM; segmenti kao Docker mreže s fiksnim podmrežama; kontejner samo na
   mrežama koje mu trebaju (varijanta A iz zadatka).
2. VM po segmentu na libvirt mrežama u route modu, host usmjerava između njih
   (varijanta B iz zadatka).
3. Dvije VM: frontend+backend na jednoj, baza na drugoj.

## Odluka

Opcija 1: jedna VM (2 vCPU, 2048 MB RAM, 12 GB qcow2) na kojoj Docker vodi
segmente kao dvije mreže s fiksnim podmrežama:

- `web` — 172.28.10.0/24 — frontend `.10`, backend `.20`
- `data` — 172.28.20.0/24 — backend `.20`, baza `.30`

Frontend je priključen **samo** na `web`, baza **samo** na `data`, a backend na
obje (jedini sloj koji smije u obje). BIND radi na istoj VM, kao sistemski
servis, i sluša i na gateway adresama Docker mreža (`172.28.10.1`,
`172.28.20.1`).

## Obrazloženje i posljedice

Varijanta B je „čišća" po hipervizoru, ali traži tri VM-a (3 × 2 GB) i ručno
usmjeravanje na hostu — na 10 GB RAM-a i pod nested virtualizacijom to je
nepouzdano, a ciklus `destroy → all` postaje dug. Varijanta A je izričito
navedena u zadatku, a njeno pravilo „kontejner samo na mrežama koje mu trebaju"
daje tačno dvije mreže: treća bi služila samo dekoraciji, jer backend mora
vidjeti i frontend i bazu.

Izolacija je posljedica topologije, ne pravila: frontend ne može do baze jer
nema interfejs u toj podmreži, a baza ne može van jer nema objavljen port.
Posljedice: svi slojevi dijele jedan kernel i jedan VM — kvar hipervizora obara
sve odjednom, a izolacija je na nivou mreže, ne mašine. Prednost je resurs,
brzina i ponovljivost ciklusa.
