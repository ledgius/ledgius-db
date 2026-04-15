-- lsmb-exempt: Ledgius-shape audit_log_immutable trigger (per R-0040 audit-trail spec) enforces append-only on the audit_log table — purposefully retained, not LSMB-era.
-- Spec references: A-0021, R-0040, R-0054.
--
-- V1.07 — Recurring Schedules, Transaction Templates, Audit Log, Exchange Rates
--
-- DDL only. Currency seed data is in R__seed_currencies.sql.
--
--   recurring_schedule    — schedules for auto-generating periodic transactions
--   transaction_template  — saved transaction templates for quick reuse
--   audit_log             — immutable tenant-level audit trail
--   exchange_rate         — daily exchange rates between currency pairs

-- =============================================================================
-- 1. Recurring Schedules
-- =============================================================================

CREATE TABLE IF NOT EXISTS recurring_schedule (
    id               SERIAL PRIMARY KEY,
    name             TEXT NOT NULL,
    description      TEXT NULL,
    source_type      TEXT NOT NULL CHECK (source_type IN ('gl', 'ar', 'ap')),
    template_json    JSONB NOT NULL,
    frequency        TEXT NOT NULL CHECK (frequency IN ('weekly', 'fortnightly', 'monthly', 'quarterly', 'annually')),
    start_date       DATE NOT NULL,
    end_date         DATE NULL,
    next_due_date    DATE NOT NULL,
    last_generated   DATE NULL,
    auto_approve     BOOLEAN NOT NULL DEFAULT false,
    active           BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE recurring_schedule IS 'Schedules for auto-generating recurring transactions (rent, subscriptions, salary)';
COMMENT ON COLUMN recurring_schedule.template_json IS 'Full transaction template as JSON (reference, lines, amounts, accounts)';
COMMENT ON COLUMN recurring_schedule.frequency IS 'weekly, fortnightly, monthly, quarterly, annually';

CREATE INDEX IF NOT EXISTS idx_recurring_active ON recurring_schedule(active, next_due_date);

-- =============================================================================
-- 2. Transaction Templates
-- =============================================================================

CREATE TABLE IF NOT EXISTS transaction_template (
    id               SERIAL PRIMARY KEY,
    name             TEXT NOT NULL,
    description      TEXT NULL,
    source_type      TEXT NOT NULL CHECK (source_type IN ('gl', 'ar', 'ap')),
    template_json    JSONB NOT NULL,
    created_by       TEXT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE transaction_template IS 'Saved transaction templates for quick reuse';

-- =============================================================================
-- 3. Audit Log (immutable)
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id            BIGSERIAL PRIMARY KEY,
    user_id       TEXT NULL,
    action        TEXT NOT NULL,
    entity_type   TEXT NOT NULL,
    entity_id     TEXT NULL,
    before_json   JSONB NULL,
    after_json    JSONB NULL,
    ip_address    TEXT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE audit_log IS 'Immutable audit trail of all state changes within a tenant. No UPDATE or DELETE permitted.';

CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log(created_at);

-- Prevent updates and deletes on audit_log.
CREATE OR REPLACE FUNCTION prevent_audit_modification() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is immutable — updates and deletes are not permitted';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS audit_log_immutable ON audit_log;
CREATE TRIGGER audit_log_immutable
    BEFORE UPDATE OR DELETE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

-- =============================================================================
-- 4. Exchange Rates
-- (currency table already exists in V1.00 from LedgerSMB schema)
-- =============================================================================

CREATE TABLE IF NOT EXISTS exchange_rate (
    id           SERIAL PRIMARY KEY,
    from_curr    CHARACTER(3) NOT NULL REFERENCES currency(curr),
    to_curr      CHARACTER(3) NOT NULL REFERENCES currency(curr),
    rate         NUMERIC(18,8) NOT NULL,
    effective_date DATE NOT NULL,
    source       TEXT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (from_curr, to_curr, effective_date)
);

COMMENT ON TABLE exchange_rate IS 'Daily exchange rates between currency pairs';
COMMENT ON COLUMN exchange_rate.source IS 'Rate source: manual, rba, ecb, etc.';

CREATE INDEX IF NOT EXISTS idx_exchange_rate_lookup ON exchange_rate(from_curr, to_curr, effective_date DESC);
