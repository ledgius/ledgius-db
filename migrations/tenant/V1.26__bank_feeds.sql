-- Spec references: R-0049, A-0025, T-0026.
-- Authoritative sources:
--   Consumer Data Standards (DSB): https://consumerdatastandardsaustralia.github.io/standards/
--   Basiq webhook security:        https://api.basiq.io/docs/webhooks-security
--   Basiq consent management:      https://api.basiq.io/docs/consent
--   CDR portal:                    https://www.cdr.gov.au/
--
-- Note: an earlier copy of this migration shipped under the legacy
-- ledgius-db/tenant/018_bank_feeds.sql path which Flyway does not read.
-- This V1.26 file is the canonical Flyway-tracked version. The legacy
-- file is removed in the same PR.

-- =============================================================================
-- 1. bank_transaction.source — distinguish feed vs manual upload
-- =============================================================================

ALTER TABLE bank_transaction
    ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'bank_transaction' AND constraint_name = 'bank_transaction_source_check'
    ) THEN
        ALTER TABLE bank_transaction
            ADD CONSTRAINT bank_transaction_source_check
            CHECK (source IN ('manual', 'feed'));
    END IF;
END $$;

COMMENT ON COLUMN bank_transaction.source IS
    'Origin of the transaction — manual upload (CSV/OFX/QIF) or automated bank feed via Basiq.';

-- =============================================================================
-- 2. Basiq provider user — one row per tenant (covers many connections)
-- =============================================================================

CREATE TABLE IF NOT EXISTS bank_feed_provider_user (
    id                  SERIAL PRIMARY KEY,
    provider            TEXT NOT NULL DEFAULT 'basiq'
        CHECK (provider IN ('basiq')),
    provider_user_id    TEXT NOT NULL,
    contact_email       TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_user_id)
);

COMMENT ON TABLE bank_feed_provider_user IS 'Provider-side user identifier for a tenant. Basiq creates one user per consumer; Ledgius treats this as one row per tenant. All bank_feed_connection rows reference this user.';
COMMENT ON COLUMN bank_feed_provider_user.provider_user_id IS 'Basiq user ID. Used in all subsequent Basiq API calls (consent token, transactions fetch).';
COMMENT ON COLUMN bank_feed_provider_user.contact_email IS 'Email address registered with Basiq for the user. Required by Basiq CreateUser API.';

-- =============================================================================
-- 3. Bank feed connection — per linked bank account
-- =============================================================================

CREATE TABLE IF NOT EXISTS bank_feed_connection (
    id                      SERIAL PRIMARY KEY,
    provider_user_id        INT NOT NULL REFERENCES bank_feed_provider_user(id),
    bank_account_id         INT NULL REFERENCES account(id),
    provider_connection_id  TEXT NOT NULL,
    provider_account_id     TEXT NOT NULL,
    institution_id          TEXT NOT NULL,
    institution_name        TEXT NOT NULL,
    account_name            TEXT,
    account_number_mask     TEXT,
    bsb                     TEXT,
    status                  TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'active', 'expiring', 'expired', 'disconnected', 'error')),
    consent_expires_at      TIMESTAMPTZ,
    last_sync_at            TIMESTAMPTZ,
    last_sync_status        TEXT
        CHECK (last_sync_status IS NULL OR last_sync_status IN ('success', 'partial', 'failed')),
    last_sync_error         TEXT,
    transactions_synced     INT NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bank_feed_connection IS 'One row per connected bank account. References bank_feed_provider_user (Basiq user) and the GL account (bank_account_id) once the user maps it. See R-0049 AC-1, AC-4.';
COMMENT ON COLUMN bank_feed_connection.bank_account_id IS 'NULL until the user maps this Basiq account to a Ledgius GL account.';
COMMENT ON COLUMN bank_feed_connection.consent_expires_at IS 'CDR consent expiry. Per CDR rules and Basiq Business Consumer Consent docs, max 12 months from grant.';
COMMENT ON COLUMN bank_feed_connection.status IS 'Lifecycle: pending (awaiting account map) -> active -> expiring (T-7) -> expired | disconnected | error.';

CREATE INDEX IF NOT EXISTS idx_bank_feed_status
    ON bank_feed_connection(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_bank_feed_provider_account
    ON bank_feed_connection(provider_user_id, provider_account_id);

-- =============================================================================
-- 4. Bank feed event journal — per-event begin/end audit (R-0049 AC-9)
-- =============================================================================

CREATE TABLE IF NOT EXISTS bank_feed_event_log (
    id                      SERIAL PRIMARY KEY,
    connection_id           INT NULL REFERENCES bank_feed_connection(id),
    provider_user_id        INT NULL REFERENCES bank_feed_provider_user(id),
    event_type              TEXT NOT NULL
        CHECK (event_type IN (
            'connection.create', 'connection.refresh', 'connection.disconnect',
            'consent.extend', 'consent.reauthorise', 'consent.revoked',
            'webhook.received', 'transactions.fetch', 'transactions.dedup',
            'expiry.check'
        )),
    started_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at            TIMESTAMPTZ NULL,
    status                  TEXT NOT NULL DEFAULT 'running'
        CHECK (status IN ('running', 'success', 'partial', 'failed')),
    transactions_fetched    INT NOT NULL DEFAULT 0,
    transactions_new        INT NOT NULL DEFAULT 0,
    transactions_duplicate  INT NOT NULL DEFAULT 0,
    sync_from               TIMESTAMPTZ NULL,
    sync_to                 TIMESTAMPTZ NULL,
    provider_job_id         TEXT NULL,
    request_payload         JSONB NULL,
    response_payload        JSONB NULL,
    error_message           TEXT NULL,
    error_payload           JSONB NULL,
    actor_user_id           INT NULL,
    actor_ip                INET NULL,
    request_id              TEXT NULL
);

COMMENT ON TABLE bank_feed_event_log IS 'Append-only journal of every live-feed event. Each event writes a single row at begin (status=running) and is updated to success/failed/partial on completion. Per R-0049 AC-9 every begin MUST have a matching end. See A-0025.';
COMMENT ON COLUMN bank_feed_event_log.event_type IS 'Discriminator for the lifecycle event being recorded — see R-0049 AC-9 table.';
COMMENT ON COLUMN bank_feed_event_log.provider_job_id IS 'Basiq job ID where applicable (connection.create, connection.refresh) — supports cross-referencing against the Basiq dashboard.';
COMMENT ON COLUMN bank_feed_event_log.request_payload IS 'Outbound request payload for this event (e.g. transactions.fetch query parameters).';
COMMENT ON COLUMN bank_feed_event_log.response_payload IS 'Inbound response payload — body for webhook.received, summary for transactions.fetch.';
COMMENT ON COLUMN bank_feed_event_log.error_payload IS 'Structured error context (HTTP status, Basiq error body, retry counts) on failure.';

CREATE INDEX IF NOT EXISTS idx_bank_feed_event_connection
    ON bank_feed_event_log(connection_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_bank_feed_event_status_unfinished
    ON bank_feed_event_log(status) WHERE status = 'running';
CREATE INDEX IF NOT EXISTS idx_bank_feed_event_type_started
    ON bank_feed_event_log(event_type, started_at DESC);
