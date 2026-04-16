-- Spec references: R-0057 (FR-008, FR-013), A-0031, A-0032.
--
-- V1.31 — Export run tables
--
-- Introduces the two tables that track individual export runs to external
-- systems (e.g. Xero) and the per-entity write outcomes within each run:
--
--   1. export_run         — one row per initiated run (any channel, any system)
--   2. export_run_entity  — one row per entity write attempt within a run
--
-- These are OPERATIONAL STATE tables. Audit of record is audit_log (R-0040).
-- Entity counts, totals, date ranges, validation report bodies live in
-- audit_log.metadata on xero.export.run.* entries, not in these tables.
-- These tables carry status, resume cursor, and per-row outcome — the
-- minimum needed to pause/resume a run and to drive idempotency.
--
-- The external_id column on export_run_entity is deliberately generic across
-- target systems (Xero returns GUIDs, MYOB and future systems may return
-- different forms). TEXT is the widest portable representation.

-- =============================================================================
-- 1. export_run — one row per initiated export to an external system
-- =============================================================================

CREATE TABLE IF NOT EXISTS export_run (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID NOT NULL,
    user_id               UUID NOT NULL,
    external_system_code  TEXT NOT NULL REFERENCES external_system(code),
    channel               TEXT NOT NULL,
    run_kind              TEXT NOT NULL DEFAULT 'documents',
    scope                 JSONB NOT NULL,
    status                TEXT NOT NULL,
    started_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at          TIMESTAMPTZ NULL,
    validation_report     JSONB NULL,
    resume_cursor         JSONB NULL
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'export_run' AND constraint_name = 'export_run_channel_check'
    ) THEN
        ALTER TABLE export_run ADD CONSTRAINT export_run_channel_check
            CHECK (channel IN ('csv', 'api'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'export_run' AND constraint_name = 'export_run_run_kind_check'
    ) THEN
        ALTER TABLE export_run ADD CONSTRAINT export_run_run_kind_check
            CHECK (run_kind IN ('documents', 'payments'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'export_run' AND constraint_name = 'export_run_status_check'
    ) THEN
        ALTER TABLE export_run ADD CONSTRAINT export_run_status_check
            CHECK (status IN (
                'validating',
                'awaiting_ack',
                'mapping',
                'writing',
                'completed',
                'partial',
                'failed',
                'paused'
            ));
    END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_export_run_tenant_system
    ON export_run (tenant_id, external_system_code, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_export_run_tenant_system_status
    ON export_run (tenant_id, external_system_code, status);

-- Partial index for scheduler / resume: find in-flight runs only.
CREATE INDEX IF NOT EXISTS idx_export_run_in_flight
    ON export_run (tenant_id, external_system_code)
    WHERE status IN ('validating', 'awaiting_ack', 'mapping', 'writing', 'paused');

-- Comments
COMMENT ON TABLE export_run IS
    'One row per initiated export to an external accounting system. Operational state only — '
    'status, resume cursor, and validation report body. Entity counts, totals, date ranges, and '
    'other summary facts live in audit_log.metadata on xero.export.run.* entries (R-0040).';

COMMENT ON COLUMN export_run.id IS 'Surrogate PK. Auto-generated UUID. Correlation key into export_run_entity and audit_log.';
COMMENT ON COLUMN export_run.tenant_id IS 'Owning tenant. No FK in tenant schema (tenant identity is managed by platform schema).';
COMMENT ON COLUMN export_run.user_id IS 'User who initiated the run. Used for audit and per-user run history.';
COMMENT ON COLUMN export_run.external_system_code IS 'FK to external_system(code). Identifies the target peer system. E.g. ''xero''.';
COMMENT ON COLUMN export_run.channel IS 'Delivery mechanism: ''csv'' (downloadable zip bundle) or ''api'' (direct push over OAuth2).';
COMMENT ON COLUMN export_run.run_kind IS 'What the run exports: ''documents'' (invoices/bills/credit notes/COA/contacts) or ''payments'' (v2 payments-only run per R-0057 FR-013).';
COMMENT ON COLUMN export_run.scope IS
    'User-requested scope as JSONB. Shape includes entity_types array, optional date_range, and system-specific flags. '
    'E.g. {"entity_types":["invoice","bill"],"date_range":{"from":"2024-01-01","to":"2024-03-31"},"inclusive_of_tax":true}';
COMMENT ON COLUMN export_run.status IS
    'Lifecycle state. Progression: validating -> awaiting_ack -> mapping -> writing -> (completed | partial | failed). '
    'Terminal states never transition further. ''paused'' is an intermediate state used when rate limits or auth expiry interrupt writing.';
COMMENT ON COLUMN export_run.started_at IS 'Timestamp the run was initiated (row creation).';
COMMENT ON COLUMN export_run.completed_at IS 'Timestamp the run reached a terminal state (completed, partial, or failed). NULL while in-flight.';
COMMENT ON COLUMN export_run.validation_report IS 'Pre-flight validation findings as JSONB. See A-0031 validator/report.go for shape.';
COMMENT ON COLUMN export_run.resume_cursor IS
    'JSONB describing where to pick up after paused/crashed runs — ordered writer list position and pending entity ids. NULL when run is terminal or hasn''t begun writing.';

COMMENT ON INDEX export_run_pkey IS
    'Primary key index on export_run.id — used for direct run lookup by id and FK resolution from export_run_entity.';
COMMENT ON INDEX idx_export_run_tenant_system IS
    'Supports run history views listing recent runs per tenant + system in reverse-chronological order.';
COMMENT ON INDEX idx_export_run_tenant_system_status IS
    'Supports status-filtered queries such as "list all failed runs for this tenant + system".';
COMMENT ON INDEX idx_export_run_in_flight IS
    'Partial index covering in-flight runs (non-terminal statuses). Used by scheduler / resume path and by UI indicators for active exports. Tiny index — most runs are in terminal state.';

-- =============================================================================
-- 2. export_run_entity — per-entity write outcome within a run
-- =============================================================================

CREATE TABLE IF NOT EXISTS export_run_entity (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    export_run_id  UUID NOT NULL REFERENCES export_run(id) ON DELETE CASCADE,
    entity_type    TEXT NOT NULL,
    source_id      UUID NOT NULL,
    external_id    TEXT NULL,
    status         TEXT NOT NULL,
    error          TEXT NULL,
    written_at     TIMESTAMPTZ NULL
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'export_run_entity' AND constraint_name = 'export_run_entity_status_check'
    ) THEN
        ALTER TABLE export_run_entity ADD CONSTRAINT export_run_entity_status_check
            CHECK (status IN ('pending', 'success', 'failed', 'skipped'));
    END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_export_run_entity_run_type
    ON export_run_entity (export_run_id, entity_type);

CREATE INDEX IF NOT EXISTS idx_export_run_entity_source
    ON export_run_entity (source_id, entity_type);

-- Partial index for reverse lookup: "which Ledgius record is this external id?"
CREATE INDEX IF NOT EXISTS idx_export_run_entity_external_id
    ON export_run_entity (external_id)
    WHERE external_id IS NOT NULL;

-- Comments
COMMENT ON TABLE export_run_entity IS
    'Per-entity write outcome within an export run. One row per (run, source entity) pair. '
    'Status transitions: pending (attempt recorded) -> success (external_id populated) | failed (error populated) | skipped (no attempt made). '
    'Presence of external_id is the authoritative idempotency signal — gap sweep and re-export both consult this table, not a watermark.';

COMMENT ON COLUMN export_run_entity.id IS 'Surrogate PK. Auto-generated UUID.';
COMMENT ON COLUMN export_run_entity.export_run_id IS 'FK to parent run. ON DELETE CASCADE: deleting a run removes its per-entity rows.';
COMMENT ON COLUMN export_run_entity.entity_type IS 'Ledgius entity type being exported. E.g. ''invoice'', ''bill'', ''credit_note'', ''account'', ''contact''.';
COMMENT ON COLUMN export_run_entity.source_id IS 'Ledgius source record id (UUID). Identifies which domain entity this row represents.';
COMMENT ON COLUMN export_run_entity.external_id IS
    'Target-system assigned identifier returned on successful write. Shape is system-specific (Xero returns GUIDs, other systems may differ) — TEXT is the portable representation. '
    'NULL while pending, populated on success, remains NULL on failure/skipped.';
COMMENT ON COLUMN export_run_entity.status IS 'Outcome of the write attempt: pending (attempt recorded, outcome not yet captured), success, failed, or skipped (e.g. already exported via prior run).';
COMMENT ON COLUMN export_run_entity.error IS 'Target-system error payload on failure. NULL otherwise. Stored as text because error shapes vary across systems and channels.';
COMMENT ON COLUMN export_run_entity.written_at IS 'Timestamp the outcome was recorded (success or failure). NULL while pending.';

COMMENT ON INDEX export_run_entity_pkey IS
    'Primary key index on export_run_entity.id — used for direct per-entity row lookup and audit correlation.';
COMMENT ON INDEX idx_export_run_entity_run_type IS
    'Supports progress views such as "how many invoices succeeded in run X?" and the orchestrator''s resume cursor reconciliation.';
COMMENT ON INDEX idx_export_run_entity_source IS
    'Supports the gap-sweep query (is this source record already exported?) and "show me the export history for this entity" UI panels.';
COMMENT ON INDEX idx_export_run_entity_external_id IS
    'Partial index on external_id (non-null rows only) for reverse lookup: which Ledgius record corresponds to this Xero GUID? Used by support queries and diagnostic tooling.';

-- =============================================================================
-- 3. Backfill PK index comments for V1.30 tables (consistency with new rule)
-- =============================================================================

COMMENT ON INDEX external_system_pkey IS
    'Primary key index on external_system.code — registry lookup and FK resolution from connection + watermark tables.';
COMMENT ON INDEX external_system_connection_pkey IS
    'Primary key index on external_system_connection.id — direct connection row lookup.';
COMMENT ON INDEX export_watermark_pkey IS
    'Composite primary key index on (tenant_id, external_system_code, entity_type) — watermark lookup is always by this triple.';
