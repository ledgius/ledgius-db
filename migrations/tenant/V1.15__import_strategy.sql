-- Spec references: A-0021.
--
-- V1.15 — Import Strategy Column
--
-- Adds the import_strategy column to import_batch_migration, which controls
-- whether imported accounts are created as new (retiring defaults) or
-- mapped onto the existing chart of accounts.

ALTER TABLE import_batch_migration
    ADD COLUMN IF NOT EXISTS import_strategy TEXT NOT NULL DEFAULT 'import_as_new';

COMMENT ON COLUMN import_batch_migration.import_strategy IS 'Import strategy: import_as_new (create source accounts, retire defaults) or map_to_existing (map to existing COA)';
