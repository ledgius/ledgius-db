-- Spec references: R-0019, A-0019.
--
-- Reconciliation workflow tables: match records, exception queue,
-- precedent memory, audit events, and period close tracking.

-- =============================================================================
-- 1. Reconciliation Match — immutable record of each match decision
-- =============================================================================

CREATE TABLE IF NOT EXISTS reconciliation_match (
    id                  BIGSERIAL PRIMARY KEY,
    bank_transaction_id BIGINT NOT NULL,
    match_type          TEXT NOT NULL CHECK (match_type IN (
                            'one_to_one', 'one_to_many', 'many_to_one',
                            'generated', 'split', 'transfer')),
    matched_entry_ids   INT[] NOT NULL DEFAULT '{}',
    match_pass          INT NOT NULL,
    confidence_score    NUMERIC(5,2) NOT NULL,
    score_components    JSONB NOT NULL DEFAULT '{}',
    explanation         TEXT NOT NULL,
    rule_id             INT,
    precedent_id        BIGINT,
    matched_by          TEXT NOT NULL,
    matched_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    auto_approved       BOOLEAN NOT NULL DEFAULT false,
    status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'reversed', 'superseded')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reconciliation_match IS 'Immutable record of each reconciliation match decision. One row per match action.';
COMMENT ON COLUMN reconciliation_match.match_type IS 'Pattern: one_to_one, one_to_many (deposit=receipts), many_to_one (payment=invoices), generated (fee/interest), split, transfer';
COMMENT ON COLUMN reconciliation_match.matched_entry_ids IS 'Array of acc_trans.entry_id values matched to this bank line';
COMMENT ON COLUMN reconciliation_match.match_pass IS 'Pipeline pass (1-5) that produced this match';
COMMENT ON COLUMN reconciliation_match.score_components IS 'JSONB breakdown: {transaction_id_exact: 100, exact_amount: 50, date_within_1: 20, ...}';
COMMENT ON COLUMN reconciliation_match.explanation IS 'Human-readable: "Exact amount $1,234.56, reference INV-10483, date +1 day"';
COMMENT ON COLUMN reconciliation_match.precedent_id IS 'FK to reconciliation_precedent if a learned pattern contributed';

CREATE INDEX IF NOT EXISTS idx_recon_match_bank_txn ON reconciliation_match(bank_transaction_id);
CREATE INDEX IF NOT EXISTS idx_recon_match_status ON reconciliation_match(status);
CREATE INDEX IF NOT EXISTS idx_recon_match_matched_by ON reconciliation_match(matched_by);

-- =============================================================================
-- 2. Reconciliation Exception — managed exception queue
-- =============================================================================

CREATE TABLE IF NOT EXISTS reconciliation_exception (
    id                  BIGSERIAL PRIMARY KEY,
    bank_transaction_id BIGINT NOT NULL,
    reason_code         TEXT NOT NULL CHECK (reason_code IN (
                            'timing_difference', 'missing_ledger', 'duplicate_bank',
                            'duplicate_ledger', 'bank_fee_unposted', 'transfer_unmatched',
                            'fx_variance', 'ambiguous_candidate', 'suspected_fraud',
                            'amount_mismatch', 'other')),
    priority            TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    owner               TEXT,
    status              TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'escalated')),
    comment_trail       JSONB NOT NULL DEFAULT '[]',
    evidence            JSONB NOT NULL DEFAULT '{}',
    snooze_until        DATE,
    materiality_amount  NUMERIC,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at         TIMESTAMPTZ,
    resolved_by         TEXT
);

COMMENT ON TABLE reconciliation_exception IS 'Managed exception queue for reconciliation items that cannot be auto-matched or need investigation.';
COMMENT ON COLUMN reconciliation_exception.reason_code IS 'Structured reason: timing_difference, missing_ledger, duplicate, fx_variance, etc.';
COMMENT ON COLUMN reconciliation_exception.comment_trail IS 'JSONB array: [{author, text, timestamp}, ...]';
COMMENT ON COLUMN reconciliation_exception.snooze_until IS 'Defer review until this date';
COMMENT ON COLUMN reconciliation_exception.materiality_amount IS 'Dollar amount for risk prioritisation';

CREATE INDEX IF NOT EXISTS idx_recon_exception_status ON reconciliation_exception(status);
CREATE INDEX IF NOT EXISTS idx_recon_exception_priority ON reconciliation_exception(priority);
CREATE INDEX IF NOT EXISTS idx_recon_exception_bank_txn ON reconciliation_exception(bank_transaction_id);
CREATE INDEX IF NOT EXISTS idx_recon_exception_owner ON reconciliation_exception(owner) WHERE owner IS NOT NULL;

-- =============================================================================
-- 3. Reconciliation Precedent — approved match memory
-- =============================================================================

CREATE TABLE IF NOT EXISTS reconciliation_precedent (
    id                  BIGSERIAL PRIMARY KEY,
    bank_account_id     INT NOT NULL,
    pattern_type        TEXT NOT NULL CHECK (pattern_type IN ('classification', 'match_rule', 'counterparty_mapping')),
    normalized_pattern  TEXT NOT NULL,
    target_account_id   INT,
    target_entity       TEXT,
    rule_definition     JSONB NOT NULL DEFAULT '{}',
    approval_count      INT NOT NULL DEFAULT 1,
    confidence_boost    NUMERIC(5,2) NOT NULL DEFAULT 3.0,
    last_approved_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reconciliation_precedent IS 'Learned patterns from approved manual matches. Boosts confidence for future similar transactions.';
COMMENT ON COLUMN reconciliation_precedent.pattern_type IS 'What was learned: classification (memo→account), match_rule (field→field), counterparty_mapping (alias→entity)';
COMMENT ON COLUMN reconciliation_precedent.normalized_pattern IS 'The normalized text/reference that triggered the precedent';
COMMENT ON COLUMN reconciliation_precedent.confidence_boost IS 'Score bonus applied: min(30, approval_count * 3)';

CREATE INDEX IF NOT EXISTS idx_recon_precedent_account ON reconciliation_precedent(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_recon_precedent_pattern ON reconciliation_precedent(normalized_pattern);
CREATE UNIQUE INDEX IF NOT EXISTS idx_recon_precedent_unique ON reconciliation_precedent(bank_account_id, pattern_type, normalized_pattern);

-- =============================================================================
-- 4. Reconciliation Audit Event — per-decision audit trail
-- =============================================================================

CREATE TABLE IF NOT EXISTS reconciliation_audit_event (
    id                  BIGSERIAL PRIMARY KEY,
    bank_transaction_id BIGINT NOT NULL,
    match_id            BIGINT,
    event_type          TEXT NOT NULL CHECK (event_type IN (
                            'auto_match', 'manual_match', 'split', 'create',
                            'transfer', 'defer', 'exclude', 'undo',
                            'bulk_accept', 'exception_create', 'exception_resolve')),
    actor               TEXT NOT NULL,
    score_components    JSONB DEFAULT '{}',
    previous_state      TEXT,
    new_state           TEXT,
    override_reason     TEXT,
    generated_journal_ids INT[] DEFAULT '{}',
    detail              JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reconciliation_audit_event IS 'Immutable audit trail for every reconciliation decision. One event per action.';

CREATE INDEX IF NOT EXISTS idx_recon_audit_bank_txn ON reconciliation_audit_event(bank_transaction_id);
CREATE INDEX IF NOT EXISTS idx_recon_audit_match ON reconciliation_audit_event(match_id) WHERE match_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_recon_audit_actor ON reconciliation_audit_event(actor);
CREATE INDEX IF NOT EXISTS idx_recon_audit_type ON reconciliation_audit_event(event_type);
CREATE INDEX IF NOT EXISTS idx_recon_audit_created ON reconciliation_audit_event(created_at);

-- =============================================================================
-- 5. Reconciliation Period — close tracking per bank account
-- =============================================================================

CREATE TABLE IF NOT EXISTS reconciliation_period (
    id                      BIGSERIAL PRIMARY KEY,
    bank_account_id         INT NOT NULL,
    period_start            DATE NOT NULL,
    period_end              DATE NOT NULL,
    statement_opening       NUMERIC NOT NULL DEFAULT 0,
    statement_closing       NUMERIC NOT NULL DEFAULT 0,
    reconciled_amount       NUMERIC NOT NULL DEFAULT 0,
    unreconciled_count      INT NOT NULL DEFAULT 0,
    unreconciled_amount     NUMERIC NOT NULL DEFAULT 0,
    auto_matched_count      INT NOT NULL DEFAULT 0,
    manual_matched_count    INT NOT NULL DEFAULT 0,
    exception_count         INT NOT NULL DEFAULT 0,
    status                  TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'closed', 'locked')),
    closed_by               TEXT,
    closed_at               TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reconciliation_period IS 'Period close tracking per bank account. Records reconciliation completeness and balance verification.';

CREATE INDEX IF NOT EXISTS idx_recon_period_account ON reconciliation_period(bank_account_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_recon_period_unique ON reconciliation_period(bank_account_id, period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_recon_period_status ON reconciliation_period(status);
