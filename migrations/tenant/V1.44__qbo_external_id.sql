-- Spec references: R-0067 (QBE-016 through QBE-018), A-0037.
--
-- V1.44 — QuickBooks Online external ID mapping for idempotent export.
--
-- Tracks the relationship between Ledgius entities and their QBO
-- counterparts. Prevents duplicate creation on re-export.

CREATE TABLE IF NOT EXISTS qbo_external_id (
    id              SERIAL PRIMARY KEY,
    entity_type     TEXT NOT NULL,
    ledgius_id      INT NOT NULL,
    qbo_id          TEXT NOT NULL,
    sync_token      TEXT NOT NULL,
    last_synced_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (entity_type, ledgius_id)
);

CREATE INDEX IF NOT EXISTS idx_qbo_external_entity
    ON qbo_external_id (entity_type, ledgius_id);

COMMENT ON TABLE qbo_external_id IS
    'Maps Ledgius entity IDs to QBO entity IDs for idempotent API export. '
    'On re-export: if mapping exists → update (with SyncToken), else → create.';
COMMENT ON COLUMN qbo_external_id.sync_token IS
    'QBO SyncToken for optimistic concurrency. Required for update operations.';
