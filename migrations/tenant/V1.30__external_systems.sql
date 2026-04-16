-- Spec references: R-0058, A-0032.
--
-- V1.30 — External Systems foundation
--
-- Introduces the three foundational tables for export (and future import)
-- integration with peer accounting systems:
--
--   1. external_system           — strongly-typed registry (lookup table)
--   2. external_system_connection — per-tenant credential binding
--   3. export_watermark           — cursor-plus-date incremental export progress
--
-- Per A-0032 consequence analysis, external_system is duplicated into each
-- tenant schema rather than living in the platform schema — this keeps the
-- FK relationships honest (PostgreSQL has no cross-schema FK support) and
-- the data is identical across tenants (seeded via R__09_seed_external_systems.sql).
--
-- Startup parity check (ledgius-api externalsystem package) asserts that
-- every Go typed constant has exactly one active registry row here, and
-- every active row has a Go constant. Mismatch aborts API boot.

-- =============================================================================
-- 1. external_system — registry of peer accounting systems
-- =============================================================================

CREATE TABLE IF NOT EXISTS external_system (
    code                  TEXT PRIMARY KEY,
    display_name          TEXT NOT NULL,
    country               TEXT NOT NULL,
    supports_import_csv   BOOLEAN NOT NULL DEFAULT FALSE,
    supports_import_api   BOOLEAN NOT NULL DEFAULT FALSE,
    supports_export_csv   BOOLEAN NOT NULL DEFAULT FALSE,
    supports_export_api   BOOLEAN NOT NULL DEFAULT FALSE,
    active                BOOLEAN NOT NULL DEFAULT TRUE,
    introduced_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'external_system'
          AND constraint_name = 'external_system_code_format'
    ) THEN
        ALTER TABLE external_system
            ADD CONSTRAINT external_system_code_format
            CHECK (code ~ '^[a-z][a-z0-9_]*$');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'external_system'
          AND constraint_name = 'external_system_country_format'
    ) THEN
        ALTER TABLE external_system
            ADD CONSTRAINT external_system_country_format
            CHECK (country ~ '^[A-Z]{2}$');
    END IF;
END $$;

COMMENT ON TABLE external_system IS
    'Registry of peer accounting systems Ledgius can interoperate with (import and/or export). '
    'Codes are stable lowercase snake_case. Startup parity check enforces alignment with Go typed constants. '
    'Rows seeded via R__09_seed_external_systems.sql.';
COMMENT ON COLUMN external_system.code IS 'Stable identifier, lowercase snake_case. Referenced by FK from connection and watermark tables. E.g. ''xero'', ''myob''.';
COMMENT ON COLUMN external_system.display_name IS 'Human-readable name for UI display. E.g. ''Xero'', ''MYOB''.';
COMMENT ON COLUMN external_system.country IS 'ISO 3166-1 alpha-2 country code — the primary market the system serves. E.g. ''AU'', ''NZ'', ''US''.';
COMMENT ON COLUMN external_system.supports_import_csv IS 'Ledgius can consume CSV/file exports from this system (TRUE) or not (FALSE).';
COMMENT ON COLUMN external_system.supports_import_api IS 'Ledgius can pull data directly via this system''s API (TRUE) or not (FALSE).';
COMMENT ON COLUMN external_system.supports_export_csv IS 'Ledgius can produce CSV bundles that this system''s importer accepts (TRUE) or not (FALSE).';
COMMENT ON COLUMN external_system.supports_export_api IS 'Ledgius can push data directly via this system''s API (TRUE) or not (FALSE).';
COMMENT ON COLUMN external_system.active IS 'Inactive rows are retained for audit traceability but may not be used for new runs or connections.';
COMMENT ON COLUMN external_system.introduced_at IS 'Timestamp when this external system was first registered. Informational — used in admin/support views.';

-- =============================================================================
-- 2. external_system_connection — per-tenant credential binding
-- =============================================================================

CREATE TABLE IF NOT EXISTS external_system_connection (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id                   UUID NOT NULL,
    external_system_code        TEXT NOT NULL REFERENCES external_system(code),
    status                      TEXT NOT NULL,
    credential_payload_enc      BYTEA NOT NULL,
    credential_schema_version   TEXT NOT NULL,
    scopes                      TEXT NULL,
    connected_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_refreshed_at           TIMESTAMPTZ NULL,
    disconnected_at             TIMESTAMPTZ NULL
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'external_system_connection'
          AND constraint_name = 'external_system_connection_status_check'
    ) THEN
        ALTER TABLE external_system_connection
            ADD CONSTRAINT external_system_connection_status_check
            CHECK (status IN ('active', 'disconnected', 'expired'));
    END IF;
END $$;

-- At most one active connection per (tenant, external_system). The
-- replace-credentials flow updates the old row to 'disconnected' and
-- inserts a new 'active' row in a single transaction; the partial unique
-- index scoped to active rows is the cleanest way to enforce this without
-- constraint-deferral gymnastics.
CREATE UNIQUE INDEX IF NOT EXISTS
    uq_external_system_connection_active
    ON external_system_connection (tenant_id, external_system_code)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS
    idx_external_system_connection_tenant
    ON external_system_connection (tenant_id, external_system_code);

COMMENT ON INDEX uq_external_system_connection_active IS
    'Enforces at most one active connection per (tenant, external_system). Uses partial unique index scoped to active rows.';
COMMENT ON INDEX idx_external_system_connection_tenant IS
    'Supports lookup of all connections (any status) for a tenant + system pair — used by connection history and audit views.';

COMMENT ON TABLE external_system_connection IS
    'Per-tenant OAuth / credential binding to an external_system. Exactly one active row per (tenant, system). '
    'Disconnecting marks the row inactive without deletion so audit history remains traceable. Credential payload '
    'shape is system-specific (see credential_schema_version) and stored encrypted with the tenant KMS key.';
COMMENT ON COLUMN external_system_connection.id IS 'Surrogate PK. Auto-generated UUID.';
COMMENT ON COLUMN external_system_connection.tenant_id IS 'Owning tenant. Combined with external_system_code forms the logical unique key (enforced via partial unique index on active rows).';
COMMENT ON COLUMN external_system_connection.external_system_code IS 'FK to external_system(code). Identifies which peer system this connection targets. E.g. ''xero''.';
COMMENT ON COLUMN external_system_connection.status IS 'Connection lifecycle state: active (usable), disconnected (user-initiated), expired (credential expired and refresh failed).';
COMMENT ON COLUMN external_system_connection.credential_payload_enc IS
    'Encrypted credential blob. Shape determined by credential_schema_version. Encrypted with tenant KMS key.';
COMMENT ON COLUMN external_system_connection.credential_schema_version IS
    'Per-system credential format identifier, e.g. ''xero.oauth2.v1''. Lets the credential payload evolve without table churn.';
COMMENT ON COLUMN external_system_connection.scopes IS 'OAuth scopes or equivalent permission set granted by the external system. Stored as space-delimited string.';
COMMENT ON COLUMN external_system_connection.connected_at IS 'Timestamp when this connection was first established (initial OAuth grant or credential save).';
COMMENT ON COLUMN external_system_connection.last_refreshed_at IS 'Timestamp of the most recent successful credential refresh (e.g. OAuth token refresh). NULL if never refreshed.';
COMMENT ON COLUMN external_system_connection.disconnected_at IS
    'Set when status transitions away from active. Preserved on reconnect so the connection audit trail is complete.';

-- =============================================================================
-- 3. export_watermark — cursor-plus-date incremental export progress
-- =============================================================================

CREATE TABLE IF NOT EXISTS export_watermark (
    tenant_id                       UUID NOT NULL,
    external_system_code            TEXT NOT NULL REFERENCES external_system(code),
    entity_type                     TEXT NOT NULL,
    last_exported_source_id         UUID NOT NULL,
    last_exported_transaction_date  DATE NOT NULL,
    last_export_run_id              UUID NOT NULL,
    last_advanced_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, external_system_code, entity_type)
);

COMMENT ON TABLE export_watermark IS
    'Cursor-plus-date watermark per (tenant, external_system, entity_type). last_exported_source_id is the primary cursor — '
    'unambiguous when multiple records share a date. last_exported_transaction_date is stored alongside for UI narrative, '
    'gap-sweep bounding, and crosscheck redundancy. Updated atomically with the run terminal-state audit_log entry.';
COMMENT ON COLUMN export_watermark.tenant_id IS 'Owning tenant. Part of the composite PK.';
COMMENT ON COLUMN export_watermark.external_system_code IS 'FK to external_system(code). Identifies which peer system this watermark tracks. E.g. ''xero''.';
COMMENT ON COLUMN export_watermark.entity_type IS 'Ledgius entity type this watermark covers. E.g. ''invoice'', ''bill'', ''credit_note'', ''account'', ''contact''.';
COMMENT ON COLUMN export_watermark.last_exported_source_id IS
    'Ledgius record id of the last successfully-exported entity for this (tenant, system, type). Primary cursor for the next run — unambiguous when multiple records share a transaction date.';
COMMENT ON COLUMN export_watermark.last_exported_transaction_date IS
    'Transaction date of the record named by last_exported_source_id. Derived but stored — bounds the gap-sweep query and drives the UI next-range preset without requiring a join to the entity table.';
COMMENT ON COLUMN export_watermark.last_export_run_id IS
    'UUID of the export_run that last advanced this watermark. Correlation key into export_run and audit_log.';
COMMENT ON COLUMN export_watermark.last_advanced_at IS
    'Server time this watermark row last advanced. Not the record''s own date — distinct from last_exported_transaction_date.';
