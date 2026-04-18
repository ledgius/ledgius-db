-- Spec references: R-0065 (REC-044–047, REC-017–020, REC-060–065), A-0036.
--
-- V1.41 — Reconciliation allocation + allocation lines + bank line status
--
-- Allocations link bank feed lines to GL entries. Split allocations
-- use multiple allocation_line rows. The bank_feed_line gains a
-- recon_status field for the lifecycle state model.

-- =============================================================================
-- 1. Allocation header
-- =============================================================================

CREATE TABLE IF NOT EXISTS recon_allocation (
    id                  SERIAL PRIMARY KEY,
    bank_feed_line_id   INT NOT NULL,
    allocation_type     TEXT NOT NULL,
    rule_id             INT REFERENCES recon_rule(id),
    total_amount        NUMERIC NOT NULL,
    status              TEXT NOT NULL DEFAULT 'pending',
    transfer_target_account_id INT REFERENCES account(id),
    allocated_by        TEXT,
    allocated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_by         TEXT,
    approved_at         TIMESTAMPTZ,
    reversed_by         TEXT,
    reversed_at         TIMESTAMPTZ
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'recon_allocation' AND constraint_name = 'recon_allocation_type_check'
    ) THEN
        ALTER TABLE recon_allocation
            ADD CONSTRAINT recon_allocation_type_check
            CHECK (allocation_type IN ('category', 'match', 'transfer'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'recon_allocation' AND constraint_name = 'recon_allocation_status_check'
    ) THEN
        ALTER TABLE recon_allocation
            ADD CONSTRAINT recon_allocation_status_check
            CHECK (status IN ('pending', 'confirmed', 'reversed'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_recon_allocation_line
    ON recon_allocation (bank_feed_line_id);

CREATE INDEX IF NOT EXISTS idx_recon_allocation_status
    ON recon_allocation (status);

COMMENT ON TABLE recon_allocation IS
    'Reconciliation allocation linking a bank feed line to GL entries. '
    'Per REC-048–059: category creates new GL, match links existing, transfer is bank-to-bank.';
COMMENT ON COLUMN recon_allocation.allocation_type IS 'category = new GL entry, match = link existing, transfer = bank-to-bank.';
COMMENT ON COLUMN recon_allocation.transfer_target_account_id IS 'For transfers: the other bank account. NULL for category/match.';

-- =============================================================================
-- 2. Allocation lines (for split allocations)
-- =============================================================================

CREATE TABLE IF NOT EXISTS recon_allocation_line (
    id              SERIAL PRIMARY KEY,
    allocation_id   INT NOT NULL REFERENCES recon_allocation(id) ON DELETE CASCADE,
    account_id      INT NOT NULL REFERENCES account(id),
    amount          NUMERIC NOT NULL,
    percentage      NUMERIC(5,2),
    description     TEXT,
    tax_code_id     INT REFERENCES tax_code(id),
    contact_id      INT
);

CREATE INDEX IF NOT EXISTS idx_recon_allocation_line_alloc
    ON recon_allocation_line (allocation_id);

COMMENT ON TABLE recon_allocation_line IS
    'Split allocation lines. Each line maps a portion of the bank transaction '
    'to a GL account with amount, percentage, description, and tax code. '
    'Per REC-017–020: 2-20 lines, must balance to total_amount.';

-- =============================================================================
-- 3. Bank feed line recon_status
-- =============================================================================

ALTER TABLE bank_feed_line
    ADD COLUMN IF NOT EXISTS recon_status TEXT NOT NULL DEFAULT 'unmatched';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'bank_feed_line' AND constraint_name = 'bank_feed_line_recon_status_check'
    ) THEN
        ALTER TABLE bank_feed_line
            ADD CONSTRAINT bank_feed_line_recon_status_check
            CHECK (recon_status IN ('unmatched', 'suggested', 'allocated', 'approved', 'reversed'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bank_feed_line_recon_status
    ON bank_feed_line (recon_status);

COMMENT ON COLUMN bank_feed_line.recon_status IS
    'Lifecycle state per REC-044: unmatched → suggested → allocated → approved → reversed. '
    'GL entries created at allocated, locked at approved.';
