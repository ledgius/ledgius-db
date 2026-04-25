-- Spec references: R-0072 (Xero Import), R-0017 (Import Pipeline).
--
-- Add staging tables for document-level imports (invoices, bills,
-- credit notes) and extend the batch table with document counters.
-- One row per LINE ITEM; lines belonging to the same document share
-- a source_number value.

-- ── Staging: invoices (sales — ACCREC) ──────────────────────────────

CREATE TABLE IF NOT EXISTS import_staging_invoice (
    id                  SERIAL PRIMARY KEY,
    batch_id            INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number          INT NOT NULL,
    source_type         TEXT NOT NULL DEFAULT 'ACCREC',
    source_number       TEXT,
    source_date         DATE,
    source_due_date     DATE,
    source_contact      TEXT,
    source_reference    TEXT,
    source_currency     TEXT,
    source_description  TEXT,
    source_quantity     NUMERIC,
    source_unit_amount  NUMERIC,
    source_account_code TEXT,
    source_tax_type     TEXT,
    source_inventory_item TEXT,
    source_status       TEXT,
    raw_data            JSONB DEFAULT '{}',
    mapped_account_id   INT,
    mapped_contact_id   INT,
    mapped_tax_code     TEXT,
    mapping_status      TEXT NOT NULL DEFAULT 'pending',
    is_valid            BOOLEAN DEFAULT TRUE,
    validation_errors   JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_invoice IS 'Staged Xero/QB invoice lines awaiting mapping and commit. One row per line item; lines sharing a source_number belong to the same invoice.';
COMMENT ON COLUMN import_staging_invoice.source_type IS 'Xero document type — ACCREC for sales invoices.';
COMMENT ON COLUMN import_staging_invoice.source_number IS 'Invoice number from source system. Repeated across lines of the same invoice. E.g. INV-0042.';
COMMENT ON COLUMN import_staging_invoice.source_tax_type IS 'Tax type display name from source system. E.g. "GST on Income", "BAS Excluded".';

CREATE INDEX IF NOT EXISTS idx_staging_invoice_batch ON import_staging_invoice(batch_id);
CREATE INDEX IF NOT EXISTS idx_staging_invoice_number ON import_staging_invoice(batch_id, source_number);

-- ── Staging: bills (purchases — ACCPAY) ─────────────────────────────

CREATE TABLE IF NOT EXISTS import_staging_bill (
    id                  SERIAL PRIMARY KEY,
    batch_id            INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number          INT NOT NULL,
    source_type         TEXT NOT NULL DEFAULT 'ACCPAY',
    source_number       TEXT,
    source_date         DATE,
    source_due_date     DATE,
    source_contact      TEXT,
    source_reference    TEXT,
    source_currency     TEXT,
    source_description  TEXT,
    source_quantity     NUMERIC,
    source_unit_amount  NUMERIC,
    source_account_code TEXT,
    source_tax_type     TEXT,
    source_status       TEXT,
    raw_data            JSONB DEFAULT '{}',
    mapped_account_id   INT,
    mapped_contact_id   INT,
    mapped_tax_code     TEXT,
    mapping_status      TEXT NOT NULL DEFAULT 'pending',
    is_valid            BOOLEAN DEFAULT TRUE,
    validation_errors   JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_bill IS 'Staged Xero/QB bill lines awaiting mapping and commit. One row per line item; lines sharing a source_number belong to the same bill.';
COMMENT ON COLUMN import_staging_bill.source_type IS 'Xero document type — ACCPAY for purchase bills.';
COMMENT ON COLUMN import_staging_bill.source_number IS 'Bill/invoice number from supplier. E.g. BILL-0017.';

CREATE INDEX IF NOT EXISTS idx_staging_bill_batch ON import_staging_bill(batch_id);
CREATE INDEX IF NOT EXISTS idx_staging_bill_number ON import_staging_bill(batch_id, source_number);

-- ── Staging: credit notes (sales or purchase) ───────────────────────

CREATE TABLE IF NOT EXISTS import_staging_credit_note (
    id                  SERIAL PRIMARY KEY,
    batch_id            INT NOT NULL REFERENCES import_batch_migration(id) ON DELETE CASCADE,
    row_number          INT NOT NULL,
    source_type         TEXT NOT NULL,
    source_direction    TEXT,
    source_number       TEXT,
    source_date         DATE,
    source_contact      TEXT,
    source_reference    TEXT,
    source_currency     TEXT,
    source_description  TEXT,
    source_quantity     NUMERIC,
    source_unit_amount  NUMERIC,
    source_account_code TEXT,
    source_tax_type     TEXT,
    source_status       TEXT,
    raw_data            JSONB DEFAULT '{}',
    mapped_account_id   INT,
    mapped_contact_id   INT,
    mapped_tax_code     TEXT,
    mapping_status      TEXT NOT NULL DEFAULT 'pending',
    is_valid            BOOLEAN DEFAULT TRUE,
    validation_errors   JSONB DEFAULT '[]',
    validation_warnings JSONB DEFAULT '[]'
);

COMMENT ON TABLE import_staging_credit_note IS 'Staged credit note lines awaiting mapping and commit. source_type is ACCRECCREDIT (sales) or ACCPAYCREDIT (purchase).';
COMMENT ON COLUMN import_staging_credit_note.source_type IS 'Xero credit note type — ACCRECCREDIT (against customer) or ACCPAYCREDIT (against supplier).';
COMMENT ON COLUMN import_staging_credit_note.source_direction IS 'Derived direction: sales or purchase.';
COMMENT ON COLUMN import_staging_credit_note.source_number IS 'Credit note number. E.g. CN-0005.';

CREATE INDEX IF NOT EXISTS idx_staging_cn_batch ON import_staging_credit_note(batch_id);
CREATE INDEX IF NOT EXISTS idx_staging_cn_number ON import_staging_credit_note(batch_id, source_number);

-- ── Extend batch table with document counters ───────────────────────

ALTER TABLE import_batch_migration
    ADD COLUMN IF NOT EXISTS invoices_total   INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS invoices_new     INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS invoices_skipped INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS bills_total      INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS bills_new        INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS bills_skipped    INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS credit_notes_total   INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS credit_notes_new     INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS credit_notes_skipped INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN import_batch_migration.invoices_total IS 'Total invoice line rows staged in this batch.';
COMMENT ON COLUMN import_batch_migration.bills_total IS 'Total bill line rows staged in this batch.';
COMMENT ON COLUMN import_batch_migration.credit_notes_total IS 'Total credit note line rows staged in this batch.';
