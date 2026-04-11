-- Migration: Add missing import_mode column to import_batch_migration.
-- This column was added to the Go model but not to the database schema.

ALTER TABLE import_batch_migration
    ADD COLUMN IF NOT EXISTS import_mode TEXT NOT NULL DEFAULT 'full_history';

COMMENT ON COLUMN import_batch_migration.import_mode IS 'Import mode: full_history or opening_balances';
