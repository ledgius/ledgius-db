-- Spec references: R-0064 (API-001, API-002), A-0035.
--
-- V1.38 — External connection table for OAuth token storage
--
-- Stores encrypted OAuth 2.0 tokens for Xero and MYOB AccountRight
-- API integrations. Tokens are encrypted at rest using AES-256-GCM
-- with the platform encryption key. One row per tenant × system.

CREATE TABLE IF NOT EXISTS external_connection (
    id                  SERIAL PRIMARY KEY,
    tenant_id           TEXT NOT NULL,
    system_code         TEXT NOT NULL,
    access_token_enc    BYTEA NOT NULL,
    refresh_token_enc   BYTEA NOT NULL,
    token_expiry        TIMESTAMPTZ NOT NULL,
    org_id              TEXT,
    org_name            TEXT,
    status              TEXT NOT NULL DEFAULT 'active',
    connected_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    connected_by        TEXT,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, system_code)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'external_connection' AND constraint_name = 'external_connection_status_check'
    ) THEN
        ALTER TABLE external_connection
            ADD CONSTRAINT external_connection_status_check
            CHECK (status IN ('active', 'expired', 'revoked'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'external_connection' AND constraint_name = 'external_connection_system_check'
    ) THEN
        ALTER TABLE external_connection
            ADD CONSTRAINT external_connection_system_check
            CHECK (system_code IN ('xero', 'myob'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_external_connection_tenant
    ON external_connection (tenant_id);

COMMENT ON TABLE external_connection IS
    'OAuth 2.0 token storage for external system API integrations (Xero, MYOB). '
    'Tokens encrypted at rest via AES-256-GCM. One row per tenant × system. '
    'Per R-0064 API-002.';

COMMENT ON COLUMN external_connection.tenant_id IS 'Ledgius tenant identifier.';
COMMENT ON COLUMN external_connection.system_code IS 'External system: xero or myob.';
COMMENT ON COLUMN external_connection.access_token_enc IS 'AES-256-GCM encrypted access token.';
COMMENT ON COLUMN external_connection.refresh_token_enc IS 'AES-256-GCM encrypted refresh token.';
COMMENT ON COLUMN external_connection.token_expiry IS 'Access token expiry timestamp. Auto-refresh triggers 2min before.';
COMMENT ON COLUMN external_connection.org_id IS 'Xero tenantId or MYOB company file GUID.';
COMMENT ON COLUMN external_connection.org_name IS 'Organisation display name from the vendor.';
COMMENT ON COLUMN external_connection.status IS 'active = tokens valid, expired = refresh failed, revoked = user disconnected.';
COMMENT ON COLUMN external_connection.connected_by IS 'User who initiated the OAuth connection.';
