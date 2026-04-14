-- Spec references: R-0019, A-0019.
--
-- Extend bank_transaction with canonical normalized fields for the
-- reconciliation matching pipeline. These columns enable structured
-- matching beyond raw description text.

-- Canonical data fields
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS value_date DATE;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS bank_transaction_code TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS counterparty_name TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS end_to_end_id TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS check_number TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS deposit_number TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS channel TEXT;

-- Normalization output
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS normalized_description TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS extracted_entities JSONB DEFAULT '{}';
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS duplicate_fingerprint TEXT;

-- Reconciliation pipeline state
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS reconciliation_status TEXT DEFAULT 'imported'
    CHECK (reconciliation_status IN ('imported', 'auto_matched', 'needs_review', 'exception', 'resolved', 'closed'));
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS confidence_score NUMERIC(5,2);
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS match_pass INT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS match_explanation JSONB DEFAULT '{}';

-- Defer/exclude state
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS deferred_reason TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS deferred_until DATE;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS exclude_reason TEXT;
ALTER TABLE bank_transaction ADD COLUMN IF NOT EXISTS excluded_by TEXT;

-- Comments
COMMENT ON COLUMN bank_transaction.value_date IS 'Value/settlement date (may differ from booking date)';
COMMENT ON COLUMN bank_transaction.counterparty_name IS 'Extracted or bank-provided counterparty name';
COMMENT ON COLUMN bank_transaction.end_to_end_id IS 'End-to-end payment reference (ISO 20022)';
COMMENT ON COLUMN bank_transaction.normalized_description IS 'Uppercased, cleaned, abbreviated-expanded description for matching';
COMMENT ON COLUMN bank_transaction.extracted_entities IS 'JSONB: invoice numbers, check numbers, order IDs extracted by normalization';
COMMENT ON COLUMN bank_transaction.duplicate_fingerprint IS 'Hash for deduplication: account_id + date + amount + normalized_description';
COMMENT ON COLUMN bank_transaction.reconciliation_status IS 'Pipeline stage: imported → auto_matched → needs_review → exception → resolved → closed';
COMMENT ON COLUMN bank_transaction.match_pass IS 'Which pipeline pass (1-5) produced the match';
COMMENT ON COLUMN bank_transaction.match_explanation IS 'JSONB score breakdown: signal weights, evidence, explanation text';

-- Indexes for pipeline queries
CREATE INDEX IF NOT EXISTS idx_bank_txn_recon_status ON bank_transaction(reconciliation_status);
CREATE INDEX IF NOT EXISTS idx_bank_txn_confidence ON bank_transaction(confidence_score) WHERE confidence_score IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bank_txn_counterparty ON bank_transaction(counterparty_name) WHERE counterparty_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bank_txn_end_to_end ON bank_transaction(end_to_end_id) WHERE end_to_end_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bank_txn_check_number ON bank_transaction(check_number) WHERE check_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bank_txn_dup_fingerprint ON bank_transaction(duplicate_fingerprint) WHERE duplicate_fingerprint IS NOT NULL;
