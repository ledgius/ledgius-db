-- Migration 012: Import staging tables for data migration pipeline
-- Supports staged, auditable, all-or-nothing imports from Xero, MYOB, and CSV.

-- =============================================================================
-- 1. Import Batch — master record for each import operation
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_batch_migration (
    id                  SERIAL PRIMARY KEY,
    source_system       TEXT NOT NULL,                   -- xero, myob, csv
    source_files        JSONB NOT NULL DEFAULT '[]',     -- [{name, size, rows, uploaded_at}]
    status              TEXT NOT NULL DEFAULT 'uploaded', -- uploaded, analysed, mapping, contacts_mapped, previewing, committing, committed, verified, failed, cancelled
    current_stage       TEXT NOT NULL DEFAULT 'upload',   -- upload, analyse, map_accounts, map_contacts, preview, commit, verify
    stage_progress      JSONB DEFAULT '{}',              -- per-stage metadata and progress

    -- Provenance
    imported_by         TEXT,                            -- user ID from JWT
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,

    -- Counts (filled as stages complete)
    accounts_total      INT DEFAULT 0,
    accounts_new        INT DEFAULT 0,
    accounts_mapped     INT DEFAULT 0,
    accounts_skipped    INT DEFAULT 0,
    contacts_total      INT DEFAULT 0,
    contacts_new        INT DEFAULT 0,
    contacts_mapped     INT DEFAULT 0,
    contacts_skipped    INT DEFAULT 0,
    txn_total           INT DEFAULT 0,
    txn_imported        INT DEFAULT 0,
    txn_skipped         INT DEFAULT 0,

    -- Verification
    source_debit_total  NUMERIC DEFAULT 0,
    source_credit_total NUMERIC DEFAULT 0,
    target_debit_total  NUMERIC DEFAULT 0,
    target_credit_total NUMERIC DEFAULT 0,
    verified            BOOLEAN DEFAULT false,

    -- Error tracking
    error_message       TEXT,
    warnings            JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_batch_migration IS 'Master record for each data import operation. Tracks progress through pipeline stages.';
COMMENT ON COLUMN import_batch_migration.status IS 'Pipeline status: uploaded → analysed → mapping → contacts_mapped → previewing → committing → committed → verified';
COMMENT ON COLUMN import_batch_migration.source_files IS 'JSON array of uploaded files with metadata [{name, size, rows, uploaded_at}]';
COMMENT ON COLUMN import_batch_migration.stage_progress IS 'Per-stage metadata, errors, and progress counters';

CREATE INDEX IF NOT EXISTS idx_import_batch_status ON import_batch_migration(status);
CREATE INDEX IF NOT EXISTS idx_import_batch_imported_by ON import_batch_migration(imported_by);

-- =============================================================================
-- 2. Staged Accounts — parsed accounts awaiting mapping
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_staging_account (
    id              SERIAL PRIMARY KEY,
    batch_id        INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number      INT NOT NULL,                       -- original row in source file

    -- Source data
    source_code     TEXT NOT NULL,
    source_name     TEXT NOT NULL,
    source_type     TEXT,                                -- as reported by source system
    source_tax_code TEXT,                                -- source default tax code
    source_currency TEXT,
    raw_data        JSONB,                               -- full original parsed row

    -- Mapping result
    mapped_to_id    INT REFERENCES account(id),          -- NULL = create new
    mapped_to_code  TEXT,                                -- target account code
    mapping_status  TEXT NOT NULL DEFAULT 'pending',      -- pending, auto, manual, skip, create
    confidence      NUMERIC(3,2) DEFAULT 0,              -- 0.00–1.00 auto-match confidence
    mapping_notes   TEXT,                                 -- user notes on why this mapping was chosen

    -- Validation
    is_valid        BOOLEAN DEFAULT true,
    validation_errors JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_account IS 'Staged accounts parsed from import files, awaiting user mapping to Ledgius chart of accounts.';
CREATE INDEX IF NOT EXISTS idx_staging_account_batch ON import_staging_account(batch_id);

-- =============================================================================
-- 3. Staged Contacts — parsed contacts awaiting mapping
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_staging_contact (
    id              SERIAL PRIMARY KEY,
    batch_id        INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number      INT NOT NULL,

    -- Source data
    source_name     TEXT NOT NULL,
    source_code     TEXT,
    source_type     TEXT,                                -- customer, vendor, both
    source_abn      TEXT,
    source_email    TEXT,
    source_phone    TEXT,
    source_currency TEXT DEFAULT 'AUD',
    source_terms    INT,
    raw_data        JSONB,

    -- Mapping result
    mapped_to_id    INT,                                 -- entity_credit_account.id if mapping to existing
    mapping_status  TEXT NOT NULL DEFAULT 'pending',      -- pending, auto, manual, skip, create
    duplicate_of    INT,                                  -- potential duplicate ECA id
    confidence      NUMERIC(3,2) DEFAULT 0,
    mapping_notes   TEXT,

    -- Validation
    is_valid        BOOLEAN DEFAULT true,
    validation_errors JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_contact IS 'Staged contacts parsed from import files, awaiting user mapping or creation.';
CREATE INDEX IF NOT EXISTS idx_staging_contact_batch ON import_staging_contact(batch_id);

-- =============================================================================
-- 4. Staged Transactions — parsed transactions awaiting commit
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_staging_transaction (
    id              SERIAL PRIMARY KEY,
    batch_id        INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number      INT NOT NULL,

    -- Source data
    source_ref      TEXT,                                -- invoice/bill/journal number
    source_date     DATE,
    source_type     TEXT,                                -- invoice, bill, credit_note, debit_note, payment, receipt, journal
    source_account  TEXT,                                -- source account code
    source_contact  TEXT,                                -- source contact name/code
    source_tax_code TEXT,
    amount          NUMERIC NOT NULL,
    tax_amount      NUMERIC DEFAULT 0,
    description     TEXT,
    source_currency TEXT DEFAULT 'AUD',
    raw_data        JSONB,

    -- Mapping result (resolved from account + contact mappings)
    mapped_account_id INT,                               -- resolved account.id
    mapped_contact_id INT,                               -- resolved entity_credit_account.id
    mapped_tax_code   TEXT,                               -- resolved Ledgius tax code
    mapping_status    TEXT NOT NULL DEFAULT 'pending',    -- pending, mapped, skip, error

    -- Validation
    is_valid        BOOLEAN DEFAULT true,
    validation_errors JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_transaction IS 'Staged transactions parsed from import files, awaiting account/contact resolution and commit.';
CREATE INDEX IF NOT EXISTS idx_staging_txn_batch ON import_staging_transaction(batch_id);
CREATE INDEX IF NOT EXISTS idx_staging_txn_type ON import_staging_transaction(batch_id, source_type);

-- =============================================================================
-- 5. Staged Tax Codes — parsed tax codes awaiting mapping
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_staging_tax_code (
    id              SERIAL PRIMARY KEY,
    batch_id        INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,

    source_code     TEXT NOT NULL,
    source_name     TEXT,
    source_rate     NUMERIC,
    raw_data        JSONB,

    mapped_to_id    INT REFERENCES tax_code(id),
    mapped_to_code  TEXT,
    mapping_status  TEXT NOT NULL DEFAULT 'pending',
    confidence      NUMERIC(3,2) DEFAULT 0
);

COMMENT ON TABLE import_staging_tax_code IS 'Staged tax codes for mapping source tax treatments to Ledgius tax codes.';
CREATE INDEX IF NOT EXISTS idx_staging_tax_batch ON import_staging_tax_code(batch_id);
