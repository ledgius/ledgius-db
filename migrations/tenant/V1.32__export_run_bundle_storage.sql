-- Spec references: R-0060 (OPS-027 through OPS-030), A-0034 (CSV bundle storage section).
--
-- V1.32 — Export run bundle storage tracking
--
-- Adds two columns to export_run for CSV-channel bundle lifecycle:
--
--   bundle_storage_key  — object storage key for the generated CSV bundle.
--                         Populated on csv-channel write completion by the
--                         orchestrator; NULL for api-channel runs.
--   bundle_purged_at    — timestamp the retention reaper deleted the bundle
--                         from object storage. NULL while the bundle is
--                         available; once set, the /bundle download endpoint
--                         returns HTTP 410 Gone.
--
-- Retention policy per R-0060 FR-028: 90 days from export_run.completed_at.
-- The reaper job (Phase D in ledgius-api) walks runs that are completed,
-- older than 90 days, and not yet purged, then deletes the object and
-- stamps bundle_purged_at in a single tx.
--
-- Index decision: deliberately no index on these columns in v1. Reaper
-- query is bounded by completed_at and runs daily — a sequential scan is
-- fine until per-tenant run counts grow materially. Revisit once a tenant
-- has >100k export_run rows.

ALTER TABLE export_run
    ADD COLUMN IF NOT EXISTS bundle_storage_key TEXT NULL,
    ADD COLUMN IF NOT EXISTS bundle_purged_at   TIMESTAMPTZ NULL;

COMMENT ON COLUMN export_run.bundle_storage_key IS
    'Object storage key for the generated CSV bundle. Populated on csv-channel write completion '
    'by the orchestrator; NULL for api-channel runs or csv runs that never reached terminal state. '
    'Shape: <bucket>/data-export/<tenant_id>/<export_run_id>.zip per A-0034. The download endpoint '
    '/data-export/runs/:id/bundle streams from this key when bundle_purged_at is NULL.';

COMMENT ON COLUMN export_run.bundle_purged_at IS
    'Timestamp the 90-day retention reaper deleted the CSV bundle from object storage (R-0060 FR-028). '
    'NULL while the bundle is still available. Once set, the /bundle download endpoint returns HTTP 410 '
    'Gone with a structured error naming this date, and the Run detail drawer renders the download link '
    'as disabled text "Bundle purged on YYYY-MM-DD (retention 90 days)" per R-0060 FR-029.';
