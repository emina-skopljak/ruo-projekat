# Frontend sloj: staticki fajlovi + nginx kao reverse proxy prema backendu.
# Namjerno nema build koraka (nema Node-a): manje tehnologija, manja slika,
# lakse objasnjavanje na odbrani. Vidi ADR DO-1 i DO-5.

FROM nginx:1.27-alpine

# Konfiguracija ide kao template; nginx je pri startu "popuni" preko envsubst.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

COPY index.html app.js /usr/share/nginx/html/

# Podrazumijevana vrijednost samo za lokalni razvoj; u VM-u je postavlja Ansible.
ENV BACKEND_URL=http://backend:8000

EXPOSE 80

# Healthcheck nije u Dockerfile-u namjerno: isti image se koristi lokalno i u
# VM-u, a parametri provjere pripadaju orkestraciji (compose.yaml / Ansible).
