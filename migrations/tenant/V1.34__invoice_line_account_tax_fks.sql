-- Spec references: R-0017 (IMP-PIP-025, §Domain Model Completeness), A-0017 (§Storage / Schema Changes).
--
-- V1.34 — Invoice line account_id + tax_id FKs
--
-- Per R-0017 IMP-PIP-025, every invoice / bill / credit-note line
-- must carry explicit FKs to account(id) and tax_code(id). Per-line
-- account and per-line tax cannot be inferred from the product or
-- silently defaulted — this is load-bearing for GL correctness, for
-- Xero export (LineItem.AccountCode + LineItem.TaxType are required
-- per the Xero API spec), and for BAS reporting (R-0032).
--
-- Strategy: add both columns nullable, backfill from the best
-- available inference source (parts linkage), then make NOT NULL in
-- a follow-up migration once data is clean. This migration only adds
-- the columns + FKs + indexes; the backfill runs as a separate
-- operational step so its progress is observable.

-- =============================================================================
-- invoice.account_id — GL account this line posts to
-- =============================================================================

ALTER TABLE invoice
    ADD COLUMN IF NOT EXISTS account_id INTEGER NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'invoice' AND constraint_name = 'invoice_account_id_fkey'
    ) THEN
        ALTER TABLE invoice
            ADD CONSTRAINT invoice_account_id_fkey
            FOREIGN KEY (account_id) REFERENCES account(id) ON DELETE RESTRICT;
    END IF;
END $$;

COMMENT ON COLUMN invoice.account_id IS
    'FK to account(id) — the GL account this line posts to. Per R-0017 IMP-PIP-025 every '
    'invoice/bill/credit-note line carries an explicit per-line account; cannot be inferred '
    'from parts_id or defaulted. Nullable during transition; follow-up migration enforces NOT '
    'NULL once legacy rows are backfilled via parts.income_accno_id / parts.expense_accno_id / '
    'user-confirmed defaults.';

-- =============================================================================
-- invoice.tax_id — tax code driving tax calculation for this line
-- =============================================================================

ALTER TABLE invoice
    ADD COLUMN IF NOT EXISTS tax_id INTEGER NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'invoice' AND constraint_name = 'invoice_tax_id_fkey'
    ) THEN
        ALTER TABLE invoice
            ADD CONSTRAINT invoice_tax_id_fkey
            FOREIGN KEY (tax_id) REFERENCES tax_code(id) ON DELETE RESTRICT;
    END IF;
END $$;

COMMENT ON COLUMN invoice.tax_id IS
    'FK to tax_code(id) — the tax code driving tax calculation for this specific line. Per '
    'R-0017 IMP-PIP-025 every invoice/bill/credit-note line carries an explicit per-line tax '
    'code; cannot be inferred from account default or tenant default. Nullable during transition; '
    'follow-up migration enforces NOT NULL once legacy rows are backfilled via parts default or '
    'user-confirmed value. Required for Xero LineItem.TaxType export (R-0057) and BAS reporting '
    '(R-0032).';

-- =============================================================================
-- Indexes for common read patterns
-- =============================================================================
--
-- "Which lines post to account X" — for the reporting / reconciliation
-- flows that drill into a specific GL account. Partial index on
-- non-null rows only (pre-backfill, most rows are NULL).
CREATE INDEX IF NOT EXISTS idx_invoice_account_id
    ON invoice (account_id)
    WHERE account_id IS NOT NULL;

-- "Which lines use tax code Y" — for BAS reporting and tax-rate
-- migration scenarios.
CREATE INDEX IF NOT EXISTS idx_invoice_tax_id
    ON invoice (tax_id)
    WHERE tax_id IS NOT NULL;

COMMENT ON INDEX idx_invoice_account_id IS
    'Partial index on invoice.account_id (non-null rows only) supporting "lines posting to '
    'account X" queries — reporting drill-downs, reconciliation, export gap-sweeps. Partial '
    'because pre-backfill the majority of legacy rows are NULL; index stays small and hot '
    'during the transition.';

COMMENT ON INDEX idx_invoice_tax_id IS
    'Partial index on invoice.tax_id (non-null rows only) supporting "lines using tax code Y" '
    'queries — BAS reporting, tax-rate migration, export gap-sweeps.';
