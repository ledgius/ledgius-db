-- Bank import tables for the Ledgius ingestion pipeline.
-- These tables exist ONLY in the Ledgius DB (not in legacy LedgerSMB).

CREATE TABLE IF NOT EXISTS import_batch (
    id              SERIAL PRIMARY KEY,
    account_id      INTEGER NOT NULL REFERENCES account(id),
    file_name       TEXT,
    file_format     TEXT,
    imported_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    total_rows      INTEGER NOT NULL DEFAULT 0,
    matched_rows    INTEGER NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS bank_transaction (
    id               SERIAL PRIMARY KEY,
    import_batch_id  INTEGER NOT NULL REFERENCES import_batch(id),
    external_id      TEXT,
    trans_date       DATE NOT NULL,
    post_date        DATE,
    amount           NUMERIC NOT NULL,
    description      TEXT,
    reference        TEXT,
    trans_type       TEXT,
    balance          NUMERIC,
    account_id       INTEGER NOT NULL REFERENCES account(id),
    matched_entry_id INTEGER,
    match_status     TEXT NOT NULL DEFAULT 'unmatched',
    matched_by       TEXT,
    rule_id          INTEGER
);

CREATE INDEX IF NOT EXISTS idx_bank_transaction_account
    ON bank_transaction(account_id, match_status);
CREATE INDEX IF NOT EXISTS idx_bank_transaction_batch
    ON bank_transaction(import_batch_id);
CREATE INDEX IF NOT EXISTS idx_bank_transaction_external
    ON bank_transaction(account_id, external_id);

CREATE TABLE IF NOT EXISTS bank_rule (
    id                  SERIAL PRIMARY KEY,
    account_id          INTEGER NOT NULL REFERENCES account(id),
    name                TEXT NOT NULL,
    description_pattern TEXT,
    reference_pattern   TEXT,
    match_account_id    INTEGER NOT NULL REFERENCES account(id),
    enabled             BOOLEAN NOT NULL DEFAULT true,
    priority            INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_bank_rule_account
    ON bank_rule(account_id, enabled);
