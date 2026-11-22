-- Inicijalna shema baze. Izvodi se samo kad je volume prazan
-- (docker-entrypoint-initdb.d). Backend dodatno radi CREATE TABLE IF NOT EXISTS,
-- pa je ponovno podizanje bezbjedno.

CREATE TABLE IF NOT EXISTS notes (
    id         BIGSERIAL PRIMARY KEY,
    body       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO notes (body) VALUES
    ('Prvi zadatak upisan pri inicijalizaciji baze'),
    ('Podatak koji mora prezivjeti ponovno kreiranje kontejnera (AO-10)');
