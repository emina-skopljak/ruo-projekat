"""
Backend sloj (FastAPI) — jedini sloj koji smije komunicirati s bazom.

Sve adrese i kredencijali dolaze iz okruzenja (vidi ADR DO-9):
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

Namjerno nema ORM-a i nema migracionog alata: dvije tabele-manje je lakse
objasniti red po red, a shema je ionako u app/db/init.sql.
"""

from __future__ import annotations

import os
import socket
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

app = FastAPI(title="RuO backend", version="1.0.0")


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


def wait_for_db() -> None:
    """Baza se moze dizati sporije od backenda; cekamo je umjesto da padnemo."""
    for attempt in range(1, CONNECT_ATTEMPTS + 1):
        try:
            with db() as conn, conn.cursor() as cur:
                cur.execute("SELECT 1")
            print(f"baza dostupna (pokusaj {attempt})", flush=True)
            return
        except psycopg.OperationalError as exc:
            print(f"baza nije spremna ({attempt}/{CONNECT_ATTEMPTS}): {exc}", flush=True)
            time.sleep(CONNECT_DELAY_SECONDS)
    raise RuntimeError(f"baza {DB_HOST}:{DB_PORT} nije dostupna")


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


@app.on_event("startup")
def on_startup() -> None:
    wait_for_db()
    ensure_schema()


@app.get("/health")
def health() -> JSONResponse:
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        return JSONResponse({"status": "ok", "database": "up", "instance": socket.gethostname()})
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
    return [
        Note(id=row[0], body=row[1], created_at=row[2].isoformat())
        for row in rows
    ]


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
def info() -> dict[str, str]:
    """Koristi se u testovima i kasnije za demonstraciju round-robin DNS-a (DO-8)."""
    return {
        "instance": socket.gethostname(),
        "db_host": DB_HOST,
        "db_name": DB_NAME,
    }
