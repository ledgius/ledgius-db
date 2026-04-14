-- Spec references: A-0021.
--
-- V1.14 — Import Batch Mode Column
--
-- Adds the import_mode column to import_batch_migration, which controls
-- whether the import loads full transaction history or only opening balances.

ALTER TABLE import_batch_migration
    ADD COLUMN IF NOT EXISTS import_mode TEXT NOT NULL DEFAULT 'full_history';

COMMENT ON COLUMN import_batch_migration.import_mode IS 'Import mode: full_history (import all historical transactions) or opening_balances (import trial balance only)';
