-- Migration: Add import_strategy column to import_batch_migration.
-- Controls whether imported accounts are created as new (default) or mapped to existing.

ALTER TABLE import_batch_migration
    ADD COLUMN IF NOT EXISTS import_strategy TEXT NOT NULL DEFAULT 'import_as_new';

COMMENT ON COLUMN import_batch_migration.import_strategy IS 'Import strategy: import_as_new (create source accounts, retire defaults) or map_to_existing (map to existing COA)';
