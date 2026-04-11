-- Migration 009: Add audit metadata columns to core tables
-- Adds created_at, updated_at, created_by, updated_by to tables that lack them.
-- These columns support the workflow-centric UX showing who/when/what on every entity.

-- ============================================================================
-- transactions (parent for all GL, AR, AP entries)
-- Already has entered_by (int FK to entity) but lacks timestamps and string user IDs.
-- ============================================================================

ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS created_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_by  text,
    ADD COLUMN IF NOT EXISTS updated_by  text;

COMMENT ON COLUMN transactions.created_at IS 'Timestamp when the transaction record was created';
COMMENT ON COLUMN transactions.updated_at IS 'Timestamp of the last modification to the transaction record';
COMMENT ON COLUMN transactions.created_by IS 'User ID (from JWT) who created this transaction, e.g. "usr_abc123"';
COMMENT ON COLUMN transactions.updated_by IS 'User ID (from JWT) who last modified this transaction';

-- ============================================================================
-- account (chart of accounts)
-- ============================================================================

ALTER TABLE account
    ADD COLUMN IF NOT EXISTS created_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_by  text,
    ADD COLUMN IF NOT EXISTS updated_by  text;

COMMENT ON COLUMN account.created_at IS 'Timestamp when the account was created';
COMMENT ON COLUMN account.updated_at IS 'Timestamp of the last modification to the account';
COMMENT ON COLUMN account.created_by IS 'User ID (from JWT) who created this account';
COMMENT ON COLUMN account.updated_by IS 'User ID (from JWT) who last modified this account';

-- ============================================================================
-- entity (base identity for contacts)
-- Already has "created" (date, not timestamptz). We add the new columns alongside.
-- ============================================================================

ALTER TABLE entity
    ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_by  text,
    ADD COLUMN IF NOT EXISTS updated_by  text;

COMMENT ON COLUMN entity.updated_at IS 'Timestamp of the last modification to the entity';
COMMENT ON COLUMN entity.created_by IS 'User ID (from JWT) who created this entity';
COMMENT ON COLUMN entity.updated_by IS 'User ID (from JWT) who last modified this entity';

-- ============================================================================
-- entity_credit_account (customer/vendor credit accounts)
-- ============================================================================

ALTER TABLE entity_credit_account
    ADD COLUMN IF NOT EXISTS created_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_by  text,
    ADD COLUMN IF NOT EXISTS updated_by  text;

COMMENT ON COLUMN entity_credit_account.created_at IS 'Timestamp when the credit account was created';
COMMENT ON COLUMN entity_credit_account.updated_at IS 'Timestamp of the last modification';
COMMENT ON COLUMN entity_credit_account.created_by IS 'User ID (from JWT) who created this credit account';
COMMENT ON COLUMN entity_credit_account.updated_by IS 'User ID (from JWT) who last modified this credit account';

-- ============================================================================
-- bank_transaction (imported bank lines)
-- ============================================================================

ALTER TABLE bank_transaction
    ADD COLUMN IF NOT EXISTS created_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_by  text,
    ADD COLUMN IF NOT EXISTS updated_by  text;

COMMENT ON COLUMN bank_transaction.created_at IS 'Timestamp when the bank transaction was imported/created';
COMMENT ON COLUMN bank_transaction.updated_at IS 'Timestamp of the last modification (e.g. matching)';
COMMENT ON COLUMN bank_transaction.created_by IS 'User ID (from JWT) who imported this transaction';
COMMENT ON COLUMN bank_transaction.updated_by IS 'User ID (from JWT) who last modified this transaction';

-- ============================================================================
-- account_heading (COA groupings)
-- ============================================================================

ALTER TABLE account_heading
    ADD COLUMN IF NOT EXISTS created_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS created_by  text,
    ADD COLUMN IF NOT EXISTS updated_by  text;

COMMENT ON COLUMN account_heading.created_at IS 'Timestamp when the heading was created';
COMMENT ON COLUMN account_heading.updated_at IS 'Timestamp of the last modification to the heading';
COMMENT ON COLUMN account_heading.created_by IS 'User ID (from JWT) who created this heading';
COMMENT ON COLUMN account_heading.updated_by IS 'User ID (from JWT) who last modified this heading';
