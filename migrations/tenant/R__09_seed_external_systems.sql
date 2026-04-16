-- Spec references: R-0058, A-0032.
--
-- R__09_seed_external_systems.sql — External Systems Registry (repeatable)
--
-- Seeds the canonical list of peer accounting systems Ledgius supports for
-- import and/or export. Capability flags are the source of truth for what
-- the UI exposes per system.
--
-- Pattern: UPSERT (INSERT ... ON CONFLICT DO UPDATE) so capability flags and
-- display metadata can be adjusted by re-running this script without losing
-- row history (FK dependents like connections and watermarks remain valid).
--
-- Adding a new system requires three steps:
--   1. Add a row here
--   2. Add a matching Go typed constant in ledgius-api/internal/externalsystem
--   3. Deploy — the startup parity check will refuse to boot if either side
--      is missing
--
-- Capability flag meanings:
--   supports_import_csv — Ledgius can consume CSV/file exports from this system
--   supports_import_api — Ledgius can pull data directly via the system's API
--   supports_export_csv — Ledgius can produce CSV bundles that this system imports
--   supports_export_api — Ledgius can push data directly via the system's API

INSERT INTO external_system
    (code, display_name, country,
     supports_import_csv, supports_import_api,
     supports_export_csv, supports_export_api,
     active)
VALUES
    -- Xero: first-class export target per R-0057. Existing Ledgius importer
    -- already consumes Xero CSV exports (R-0017).
    ('xero', 'Xero', 'AU', TRUE,  FALSE, TRUE,  TRUE,  TRUE),

    -- MYOB: existing Ledgius importer consumes MYOB AO / AE MAS / CeeData exports
    -- (R-0017). Export to MYOB deferred to a future spec — both export flags stay
    -- FALSE until that spec lands and the corresponding Go implementation exists.
    ('myob', 'MYOB', 'AU', TRUE,  FALSE, FALSE, FALSE, TRUE)

ON CONFLICT (code) DO UPDATE SET
    display_name        = EXCLUDED.display_name,
    country             = EXCLUDED.country,
    supports_import_csv = EXCLUDED.supports_import_csv,
    supports_import_api = EXCLUDED.supports_import_api,
    supports_export_csv = EXCLUDED.supports_export_csv,
    supports_export_api = EXCLUDED.supports_export_api,
    active              = EXCLUDED.active;
