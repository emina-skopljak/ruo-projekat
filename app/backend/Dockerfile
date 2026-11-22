# Backend sloj: multi-stage build (vidi ADR DO-5).
#   stage 1 (build)  — instalira zavisnosti u izolovan prefiks
#   stage 2 (runtime) — nosi samo instaliran paket(i) i kod, bez kompajlera
# Rezultat: manja slika i nema build alata u produkcijskom kontejneru.

FROM python:3.12-slim AS build

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt


FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DB_PORT=5432

COPY --from=build /install /usr/local

WORKDIR /app
COPY main.py .

# Kontejner ne radi kao root.
RUN useradd --system --uid 10001 --no-create-home appuser
USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
