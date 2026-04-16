-- Spec references: R-0040 (AUD-002c).
--
-- V1.29 — Audit log metadata column
--
-- Adds a free-form JSONB metadata column to audit_log so long-running and
-- cross-domain operations (import runs, export runs, watermark advances,
-- etc.) can record operation-specific context without schema churn.
--
-- Convention: the JSONB payload MUST include a schema_version key
-- (e.g. 'xero_export.v1', 'export_watermark.v1') so consumers can parse
-- the rest of the object reliably. Keys specific to a single action are
-- otherwise free-form per action.
--
-- This is NOT a replacement for before_json / after_json — those remain
-- the channel for entity snapshots. metadata captures facts that do not
-- belong in an entity snapshot: run correlation ids, entity counts,
-- totals, date ranges, source file names, and so on.

ALTER TABLE audit_log
    ADD COLUMN IF NOT EXISTS metadata JSONB;

COMMENT ON COLUMN audit_log.metadata IS
    'Operation-specific context. Free-form JSONB per action; must include schema_version key. '
    'Used for import/export run summaries (counts, totals, date ranges), correlation ids into '
    'long-running operation tables, and other facts that do not belong in before_json/after_json.';
