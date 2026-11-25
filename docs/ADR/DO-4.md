# DO-4: Porijeklo bazne slike VM-a

Status: prihvaćeno

## Kontekst

AO-4 traži da početnu konfiguraciju VM-a radi cloud-init: korisnik za
upravljanje sa SSH ključem i prijava lozinkom onemogućena. Treba odlučiti odakle
dolazi bazna slika i kako se konfiguracija ubacuje pri prvom bootu.

## Razmotrene opcije

1. Javna Ubuntu cloud slika + `cloud-localds` seed (NoCloud) sa user-data,
   meta-data i network-config.
2. Vlastita slika izgrađena Packerom, sa već ugrađenim korisnikom i ključem.
3. Instalacija sa ISO-a, ručno ili poluautomatski (autoinstall).

## Odluka

Opcija 1: `noble-server-cloudimg-amd64.img` se preuzima jednom u
`~/.cache/ruo/`, provjerava checksumom i uvozi u libvirt pool. Terraform iz
šablona renderuje `user-data`, `meta-data` i `network-config`, pakuje ih u seed
ISO i dodaje ga VM-u kao prvi disk.

## Obrazloženje i posljedice

Packer bi dodao alat, build korak i vrijeme, a ne bi donio ni jedan bod — slika
bi i dalje morala prolaziti kroz isti cloud-init za mrežu i ključ. ISO
instalacija nije „kao kod": zahtijeva interakciju ili dodatni autoinstall
mehanizam.

Posljedice: slika je nepromijenjena i poznata (dobra strana za sigurnost i
ponovljivost), a sve što je specifično za projekat je u tri tekstualna fajla
pod verzijom u Gitu — što je i poenta AO-4. Slabost: pri svakom `destroy`
slika se ponovo uvozi u pool (nekoliko sekundi), i prvi boot traje 30–90 s dok
cloud-init ne završi.
