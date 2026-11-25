"""
Backend sloj (FastAPI) — jedini sloj koji smije komunicirati s bazom.

Sve adrese i kredencijali dolaze iz okruzenja (vidi ADR DO-9):
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

Vazno (i cesto mjesto greske): baza se NE ceka u startup handleru.
Uvicorn otvara socket tek kad startup handler zavrsi, pa bi cekanje na bazu
znacilo "port 8000 ne postoji dok baza ne proradi" — a to je upravo uzrok
502 greske na frontendu. Zato se baza priprema u pozadinskoj niti, a servis
odmah slusa; dok baza nije spremna, /health vraca 503.
"""

from __future__ import annotations

import os
import socket
import threading
import time
from contextlib import contextmanager
from typing import Iterator

import psycopg
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "notes")
DB_USER = os.environ.get("DB_USER", "notes")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

CONNECT_ATTEMPTS = 30
CONNECT_DELAY_SECONDS = 2

# Postavlja se kad je shema spremna; koristi ga /health i /api/info.
schema_ready = threading.Event()

app = FastAPI(title="RuO backend", version="1.1.0")


class NoteIn(BaseModel):
    body: str = Field(min_length=1, max_length=200)


class Note(BaseModel):
    id: int
    body: str
    created_at: str


def dsn() -> str:
    return (
        f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} "
        f"user={DB_USER} password={DB_PASSWORD} connect_timeout=3"
    )


@contextmanager
def db() -> Iterator[psycopg.Connection]:
    """Jedna konekcija po zahtjevu — dovoljno za demo, bez pooling slozenosti."""
    with psycopg.connect(dsn()) as conn:
        yield conn


def ensure_schema() -> None:
    """Idempotentno: tabela postoji i kad volume nije svjez."""
    with db() as conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS notes (
                id         BIGSERIAL PRIMARY KEY,
                body       TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )
        conn.commit()


def bootstrap() -> None:
    """Priprema bazu u pozadini, bez blokiranja HTTP servera."""
    for attempt in range(1, CONNECT_ATTEMPTS + 1):
        try:
            ensure_schema()
            schema_ready.set()
            print(f"baza spremna (pokusaj {attempt})", flush=True)
            return
        except psycopg.OperationalError as exc:
            # Najcesci slucajevi: baza se jos dize ili lozinka ne odgovara
            # (volume inicijalizovan sa drugom lozinkom).
            print(f"baza nije spremna ({attempt}/{CONNECT_ATTEMPTS}): {exc}", flush=True)
        except psycopg.Error as exc:
            print(f"greska pri pripremi sheme ({attempt}/{CONNECT_ATTEMPTS}): {exc}", flush=True)
        time.sleep(CONNECT_DELAY_SECONDS)
    print("UPOZORENJE: baza nije pripremljena; /health ce vracati 503", flush=True)


@app.on_event("startup")
def on_startup() -> None:
    print(
        f"backend start: db={DB_HOST}:{DB_PORT}/{DB_NAME} user={DB_USER} "
        f"instance={socket.gethostname()}",
        flush=True,
    )
    threading.Thread(target=bootstrap, name="db-bootstrap", daemon=True).start()


@app.get("/health")
def health() -> JSONResponse:
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        payload = {
            "status": "ok",
            "database": "up",
            "schema_ready": schema_ready.is_set(),
            "instance": socket.gethostname(),
        }
        return JSONResponse(payload)
    except psycopg.Error as exc:
        return JSONResponse(
            {"status": "degraded", "database": "down", "error": str(exc)},
            status_code=503,
        )


@app.get("/api/notes", response_model=list[Note])
def list_notes() -> list[Note]:
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, body, created_at FROM notes ORDER BY created_at DESC, id DESC")
        rows = cur.fetchall()
    return [Note(id=row[0], body=row[1], created_at=row[2].isoformat()) for row in rows]


@app.post("/api/notes", response_model=Note, status_code=201)
def create_note(note: NoteIn) -> Note:
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO notes (body) VALUES (%s) RETURNING id, body, created_at",
                (note.body.strip(),),
            )
            row = cur.fetchone()
            conn.commit()
    except psycopg.Error as exc:
        raise HTTPException(status_code=503, detail=f"baza nedostupna: {exc}") from exc
    return Note(id=row[0], body=row[1], created_at=row[2].isoformat())


@app.get("/api/info")
def info() -> dict[str, object]:
    """Koristi se u testovima i za demonstraciju da imena idu kroz zonu."""
    return {
        "instance": socket.gethostname(),
        "db_host": DB_HOST,
        "db_name": DB_NAME,
        "schema_ready": schema_ready.is_set(),
    }
