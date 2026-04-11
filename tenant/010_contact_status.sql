-- Migration 010: Add status column to entity_credit_account
-- Supports Active / OnHold / Archived lifecycle per state machine spec.

ALTER TABLE entity_credit_account
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

COMMENT ON COLUMN entity_credit_account.status IS 'Contact lifecycle: active, on_hold, archived';
