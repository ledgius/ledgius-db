-- Spec references: A-0021.
--
-- V1.12 — Import Staging Tables
--
-- Creates the staged data migration pipeline tables used during initial
-- data import from Xero, MYOB, and CSV sources. Each import operation is
-- tracked as a batch, with individual staged records for accounts, contacts,
-- transactions, and tax codes awaiting user mapping before commit.
--
--   import_batch_migration      — master record for each import operation
--   import_staging_account      — parsed accounts awaiting COA mapping
--   import_staging_contact      — parsed contacts awaiting mapping or creation
--   import_staging_transaction  — parsed transactions awaiting account/contact resolution
--   import_staging_tax_code     — parsed tax codes awaiting Ledgius code mapping

-- =============================================================================
-- 1. Import Batch Migration — master record per import operation
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_batch_migration (
    id                  SERIAL PRIMARY KEY,
    source_system       TEXT NOT NULL,
    source_files        JSONB NOT NULL DEFAULT '[]',
    status              TEXT NOT NULL DEFAULT 'uploaded',
    current_stage       TEXT NOT NULL DEFAULT 'upload',
    stage_progress      JSONB DEFAULT '{}',

    imported_by         TEXT,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,

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

    source_debit_total  NUMERIC DEFAULT 0,
    source_credit_total NUMERIC DEFAULT 0,
    target_debit_total  NUMERIC DEFAULT 0,
    target_credit_total NUMERIC DEFAULT 0,
    verified            BOOLEAN DEFAULT false,

    error_message       TEXT,
    warnings            JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_batch_migration IS 'Master record for each data import operation. Tracks progress through pipeline stages.';
COMMENT ON COLUMN import_batch_migration.status IS 'Pipeline status: uploaded → analysed → mapping → contacts_mapped → previewing → committing → committed → verified';
COMMENT ON COLUMN import_batch_migration.source_system IS 'Source system: xero, myob, csv';
COMMENT ON COLUMN import_batch_migration.source_files IS 'JSON array of uploaded files with metadata [{name, size, rows, uploaded_at}]';
COMMENT ON COLUMN import_batch_migration.current_stage IS 'Current pipeline stage: upload, analyse, map_accounts, map_contacts, preview, commit, verify';
COMMENT ON COLUMN import_batch_migration.stage_progress IS 'Per-stage metadata, errors, and progress counters';

CREATE INDEX IF NOT EXISTS idx_import_batch_status ON import_batch_migration(status);
CREATE INDEX IF NOT EXISTS idx_import_batch_imported_by ON import_batch_migration(imported_by);

-- =============================================================================
-- 2. Staged Accounts — parsed accounts awaiting mapping
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_staging_account (
    id              SERIAL PRIMARY KEY,
    batch_id        INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number      INT NOT NULL,

    source_code     TEXT NOT NULL,
    source_name     TEXT NOT NULL,
    source_type     TEXT,
    source_tax_code TEXT,
    source_currency TEXT,
    raw_data        JSONB,

    mapped_to_id    INT REFERENCES account(id),
    mapped_to_code  TEXT,
    mapping_status  TEXT NOT NULL DEFAULT 'pending',
    confidence      NUMERIC(3,2) DEFAULT 0,
    mapping_notes   TEXT,

    is_valid        BOOLEAN DEFAULT true,
    validation_errors JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_account IS 'Staged accounts parsed from import files, awaiting user mapping to Ledgius chart of accounts.';
COMMENT ON COLUMN import_staging_account.mapping_status IS 'pending, auto, manual, skip, create';
COMMENT ON COLUMN import_staging_account.confidence IS 'Auto-match confidence score 0.00–1.00';
COMMENT ON COLUMN import_staging_account.row_number IS 'Original row number in the source file for traceability';

CREATE INDEX IF NOT EXISTS idx_staging_account_batch ON import_staging_account(batch_id);

-- =============================================================================
-- 3. Staged Contacts — parsed contacts awaiting mapping
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_staging_contact (
    id              SERIAL PRIMARY KEY,
    batch_id        INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number      INT NOT NULL,

    source_name     TEXT NOT NULL,
    source_code     TEXT,
    source_type     TEXT,
    source_abn      TEXT,
    source_email    TEXT,
    source_phone    TEXT,
    source_currency TEXT DEFAULT 'AUD',
    source_terms    INT,
    raw_data        JSONB,

    mapped_to_id    INT,
    mapping_status  TEXT NOT NULL DEFAULT 'pending',
    duplicate_of    INT,
    confidence      NUMERIC(3,2) DEFAULT 0,
    mapping_notes   TEXT,

    is_valid        BOOLEAN DEFAULT true,
    validation_errors JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_contact IS 'Staged contacts parsed from import files, awaiting user mapping or creation.';
COMMENT ON COLUMN import_staging_contact.mapping_status IS 'pending, auto, manual, skip, create';
COMMENT ON COLUMN import_staging_contact.mapped_to_id IS 'entity_credit_account.id if mapping to an existing contact';
COMMENT ON COLUMN import_staging_contact.duplicate_of IS 'Potential duplicate entity_credit_account.id';

CREATE INDEX IF NOT EXISTS idx_staging_contact_batch ON import_staging_contact(batch_id);

-- =============================================================================
-- 4. Staged Transactions — parsed transactions awaiting commit
-- =============================================================================

CREATE TABLE IF NOT EXISTS import_staging_transaction (
    id              SERIAL PRIMARY KEY,
    batch_id        INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number      INT NOT NULL,

    source_ref      TEXT,
    source_date     DATE,
    source_type     TEXT,
    source_account  TEXT,
    source_contact  TEXT,
    source_tax_code TEXT,
    amount          NUMERIC NOT NULL,
    tax_amount      NUMERIC DEFAULT 0,
    description     TEXT,
    source_currency TEXT DEFAULT 'AUD',
    raw_data        JSONB,

    mapped_account_id INT,
    mapped_contact_id INT,
    mapped_tax_code   TEXT,
    mapping_status    TEXT NOT NULL DEFAULT 'pending',

    is_valid        BOOLEAN DEFAULT true,
    validation_errors JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_transaction IS 'Staged transactions parsed from import files, awaiting account/contact resolution and commit.';
COMMENT ON COLUMN import_staging_transaction.source_type IS 'invoice, bill, credit_note, debit_note, payment, receipt, journal';
COMMENT ON COLUMN import_staging_transaction.mapping_status IS 'pending, mapped, skip, error';

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
COMMENT ON COLUMN import_staging_tax_code.mapping_status IS 'pending, auto, manual, skip';

CREATE INDEX IF NOT EXISTS idx_staging_tax_batch ON import_staging_tax_code(batch_id);
