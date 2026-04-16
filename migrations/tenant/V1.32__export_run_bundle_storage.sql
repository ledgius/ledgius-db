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
-- Indexing strategy: the reaper is a known scheduled query with a
-- well-defined predicate, so it gets a targeted partial index at
-- introduction time — not "revisit later when rows grow." See below.

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

-- =============================================================================
-- Reaper candidate index (partial, on the exact predicate the reaper uses)
-- =============================================================================
--
-- The 90-day retention reaper runs daily and scans for:
--
--   SELECT id, bundle_storage_key, tenant_id
--     FROM export_run
--    WHERE bundle_purged_at  IS NULL
--      AND bundle_storage_key IS NOT NULL
--      AND completed_at       < now() - INTERVAL '90 days'
--    ORDER BY completed_at ASC;
--
-- A full table scan grows linearly with total run history — every completed
-- run, successful or not, persists in export_run forever. At scale this is
-- the kind of background query that silently degrades until a customer
-- reports slowness. Indexing at migration time is cheaper than retrofitting
-- on a populated production table.
--
-- Partial index rationale: the predicate only matches "has a bundle, not
-- yet purged" rows — by construction this is at most the last ~90 days of
-- csv-channel runs. api-channel runs never match (bundle_storage_key stays
-- NULL). Purged rows drop out of the index as bundle_purged_at lands.
-- Write overhead is near zero because most inserts don't satisfy the
-- condition, and the index stays tiny (bounded by retention window × csv
-- run rate, not total history). Ordered by completed_at so the reaper's
-- range scan is index-ordered.

CREATE INDEX IF NOT EXISTS idx_export_run_reap_candidates
    ON export_run (completed_at)
    WHERE bundle_purged_at  IS NULL
      AND bundle_storage_key IS NOT NULL;

COMMENT ON INDEX idx_export_run_reap_candidates IS
    'Partial index supporting the 90-day bundle retention reaper (R-0060 FR-028). '
    'Matches only "has a bundle, not yet purged" rows — bounded by retention window × csv run rate, '
    'not total history. Reaper query: WHERE bundle_purged_at IS NULL AND bundle_storage_key IS NOT NULL '
    'AND completed_at < now() - interval ''90 days''.';
