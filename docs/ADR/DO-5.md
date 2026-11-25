# DO-5: Gradnja i distribucija kontejnerskih slika

Status: prihvaćeno

## Kontekst

AO-1 traži tri kontejnera, a AO-2 da se cijelo okruženje podigne dokumentovanim
nizom naredbi, bez ručnih koraka. Treba odlučiti gdje se slike grade i kako
stižu na VM.

## Razmotrene opcije

1. Build na ciljnoj VM (`docker compose build` unutar VM-a), multi-stage
   Dockerfile, bez registry-ja.
2. Build lokalno na hostu, pa `docker save` / `docker load` u VM.
3. Build lokalno, push u registry (Docker Hub ili lokalni), VM povlači slike.

## Odluka

Opcija 1: multi-stage Dockerfile (build stage → slim runtime) i build na VM-u,
koji pokreće Ansible rola `app` unutar `docker compose up -d --build`.

## Obrazloženje i posljedice

Registry bi dodao vanjsku zavisnost (mreža, kredencijali, tagovi) i još jedan
sloj koji se može pokvariti na odbrani, a `save/load` bi značio ručni korak ili
dodatnu skriptu za svaku izmjenu koda. Build na ciljnoj VM je najkraći put od
izvora do pokrenutog kontejnera i staje u `make deploy`.

Posljedice: VM mora imati izlaz na internet pri prvom buildu (bazne slike i
`pip install`), a build troši CPU/RAM VM-a — zato je multi-stage bitan: runtime
slika ne nosi kompajlere ni pip keš. Slabost: build na VM-u nije „immutable
artifact" i ne može se promovirati između okolina; u produkciji bi se koristio
registry i pinovani digest-i.
