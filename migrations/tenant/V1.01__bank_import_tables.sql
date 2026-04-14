-- Spec references: A-0021.
--
-- V1.01 — Bank Import Tables
--
-- Creates tables for the bank statement import and reconciliation pipeline:
--   import_batch     — master record per import file/session
--   bank_transaction — individual parsed bank statement lines
--   bank_rule        — auto-matching rules for reconciliation
--
-- FKs to `account` are safe: account is created in V1.00.

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

COMMENT ON TABLE import_batch IS 'Master record for each bank statement import session';
COMMENT ON COLUMN import_batch.status IS 'pending, processing, complete, failed';
COMMENT ON COLUMN import_batch.file_format IS 'Detected file format: ofx, csv, qif, myob';

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
    rule_id          INTEGER,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by       TEXT,
    updated_by       TEXT
);

COMMENT ON TABLE bank_transaction IS 'Individual bank statement lines parsed from imported files';
COMMENT ON COLUMN bank_transaction.match_status IS 'unmatched, matched, reconciled, ignored';
COMMENT ON COLUMN bank_transaction.external_id IS 'Bank-assigned transaction ID for deduplication';
COMMENT ON COLUMN bank_transaction.matched_by IS 'manual or rule_id value when auto-matched';

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

COMMENT ON TABLE bank_rule IS 'Auto-matching rules for bank reconciliation — applied in priority order';
COMMENT ON COLUMN bank_rule.description_pattern IS 'Regex pattern matched against bank_transaction.description';
COMMENT ON COLUMN bank_rule.reference_pattern IS 'Regex pattern matched against bank_transaction.reference';
COMMENT ON COLUMN bank_rule.match_account_id IS 'GL account to post matched transactions against';

CREATE INDEX IF NOT EXISTS idx_bank_rule_account
    ON bank_rule(account_id, enabled);
