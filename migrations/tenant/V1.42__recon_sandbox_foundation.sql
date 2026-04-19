-- Spec references: R-0065 (REC-044, REC-024c, REC-024d), A-0036.
--
-- V1.42 — Reconciliation sandbox foundation
--
-- Introduces the two-field status model (allocation_method + workflow_status)
-- on bank_transaction, extends recon_rule with priority/direction/amount matching,
-- and extends recon_allocation for the booking sandbox (propose → approve).
-- GL entries are ONLY created at approval, never at propose.

-- =============================================================================
-- 1. Bank feed line: two-field lifecycle
-- =============================================================================

ALTER TABLE bank_transaction
    ADD COLUMN IF NOT EXISTS allocation_method TEXT,
    ADD COLUMN IF NOT EXISTS workflow_status TEXT NOT NULL DEFAULT 'imported';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'bank_transaction' AND constraint_name = 'bank_transaction_workflow_status_check'
    ) THEN
        ALTER TABLE bank_transaction
            ADD CONSTRAINT bank_transaction_workflow_status_check
            CHECK (workflow_status IN ('imported', 'unallocated', 'proposed', 'approved'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'bank_transaction' AND constraint_name = 'bank_transaction_allocation_method_check'
    ) THEN
        ALTER TABLE bank_transaction
            ADD CONSTRAINT bank_transaction_allocation_method_check
            CHECK (allocation_method IS NULL OR allocation_method IN (
                'rule_match', 'manual_allocation', 'linked_auto', 'linked_manual',
                'transfer', 'excluded', 'deferred'
            ));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bank_transaction_workflow
    ON bank_transaction (workflow_status);

CREATE INDEX IF NOT EXISTS idx_bank_transaction_method
    ON bank_transaction (allocation_method)
    WHERE allocation_method IS NOT NULL;

COMMENT ON COLUMN bank_transaction.workflow_status IS
    'Lifecycle state: imported → unallocated (rules ran, no match) → proposed (allocation exists, no GL) → approved (GL committed).';
COMMENT ON COLUMN bank_transaction.allocation_method IS
    'How the line was resolved: rule_match, manual_allocation, linked_auto, linked_manual, transfer, excluded, deferred. NULL when unallocated/imported.';

-- =============================================================================
-- 2. Recon rule: priority, direction, amount matching
-- =============================================================================

ALTER TABLE recon_rule
    ADD COLUMN IF NOT EXISTS enabled BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS priority INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS direction TEXT NOT NULL DEFAULT 'any',
    ADD COLUMN IF NOT EXISTS amount_match_type TEXT NOT NULL DEFAULT 'any',
    ADD COLUMN IF NOT EXISTS amount_match_value JSONB;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'recon_rule' AND constraint_name = 'recon_rule_direction_check'
    ) THEN
        ALTER TABLE recon_rule
            ADD CONSTRAINT recon_rule_direction_check
            CHECK (direction IN ('withdrawal', 'deposit', 'any'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'recon_rule' AND constraint_name = 'recon_rule_amount_match_type_check'
    ) THEN
        ALTER TABLE recon_rule
            ADD CONSTRAINT recon_rule_amount_match_type_check
            CHECK (amount_match_type IN ('any', 'exact', 'set', 'range'));
    END IF;
END $$;

-- Migrate existing 'disabled' flag to new 'enabled' flag
UPDATE recon_rule SET enabled = NOT disabled WHERE disabled = true;

COMMENT ON COLUMN recon_rule.enabled IS 'Active rules participate in matching. Disabled rules retained for audit (REC-074).';
COMMENT ON COLUMN recon_rule.priority IS 'Manual ordering: lower value = higher precedence. Used in rules management drawer.';
COMMENT ON COLUMN recon_rule.direction IS 'Direction compatibility: withdrawal, deposit, or any. Incompatible matches shown as suggestions only (REC-072).';
COMMENT ON COLUMN recon_rule.amount_match_type IS 'Amount matching: any (no filter), exact, set (comma list), range (min/max).';
COMMENT ON COLUMN recon_rule.amount_match_value IS 'Amount criteria: {"value": 100} for exact, {"values": [38,43,68]} for set, {"min": 40, "max": 500} for range.';

-- =============================================================================
-- 3. Recon allocation: sandbox fields
-- =============================================================================

-- Replace old allocation_type + status with new two-field model
ALTER TABLE recon_allocation
    ADD COLUMN IF NOT EXISTS allocation_method TEXT,
    ADD COLUMN IF NOT EXISTS workflow_status TEXT NOT NULL DEFAULT 'proposed',
    ADD COLUMN IF NOT EXISTS counterpart_bank_transaction_id INT,
    ADD COLUMN IF NOT EXISTS transfer_status TEXT;

-- Migrate existing data: map old allocation_type to new allocation_method
UPDATE recon_allocation
SET allocation_method = CASE
    WHEN allocation_type = 'category' THEN 'manual_allocation'
    WHEN allocation_type = 'match' THEN 'linked_manual'
    WHEN allocation_type = 'transfer' THEN 'transfer'
    ELSE 'manual_allocation'
END
WHERE allocation_method IS NULL AND allocation_type IS NOT NULL;

-- Migrate old status to new workflow_status
UPDATE recon_allocation
SET workflow_status = CASE
    WHEN status = 'confirmed' THEN 'approved'
    WHEN status = 'reversed' THEN 'approved'
    ELSE 'proposed'
END
WHERE workflow_status = 'proposed' AND status IS NOT NULL AND status != 'pending';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'recon_allocation' AND constraint_name = 'recon_allocation_workflow_status_check'
    ) THEN
        ALTER TABLE recon_allocation
            ADD CONSTRAINT recon_allocation_workflow_status_check
            CHECK (workflow_status IN ('proposed', 'approved'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'recon_allocation' AND constraint_name = 'recon_allocation_method_check'
    ) THEN
        ALTER TABLE recon_allocation
            ADD CONSTRAINT recon_allocation_method_check
            CHECK (allocation_method IN (
                'rule_match', 'manual_allocation', 'linked_auto', 'linked_manual',
                'transfer', 'excluded', 'deferred'
            ));
    END IF;
END $$;

-- Only one active allocation per bank feed line (REC-024d)
CREATE UNIQUE INDEX IF NOT EXISTS idx_recon_allocation_active
    ON recon_allocation (bank_transaction_id)
    WHERE workflow_status IN ('proposed', 'approved');

COMMENT ON COLUMN recon_allocation.allocation_method IS 'How this allocation was created: rule_match, manual_allocation, linked_auto, linked_manual, transfer, excluded, deferred.';
COMMENT ON COLUMN recon_allocation.workflow_status IS 'Sandbox lifecycle: proposed (no GL impact) → approved (GL entries created).';
COMMENT ON COLUMN recon_allocation.counterpart_bank_transaction_id IS 'For transfers: the paired bank feed line on the other account.';
COMMENT ON COLUMN recon_allocation.transfer_status IS 'Transfer state: pending_counterpart (one side only), matched (both sides found), approved.';

-- =============================================================================
-- 4. Smart reconciliation rejection log
-- =============================================================================

CREATE TABLE IF NOT EXISTS smart_recon_rejection (
    id                  SERIAL PRIMARY KEY,
    bank_transaction_id   INT NOT NULL,
    rule_id             INT REFERENCES recon_rule(id),
    reason              TEXT NOT NULL,
    actor               TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_smart_recon_rejection_rule
    ON smart_recon_rejection (rule_id);

COMMENT ON TABLE smart_recon_rejection IS
    'Log of rejected smart reconciliation suggestions. Used to reduce rule confidence after repeated rejections (REC-038b).';

-- =============================================================================
-- 5. Smart reconciliation stats view
-- =============================================================================

CREATE OR REPLACE VIEW smart_recon_stats AS
SELECT
    r.id AS rule_id,
    r.name,
    r.source,
    r.use_count AS confirmations,
    r.rejection_count AS rejections,
    CASE WHEN (r.use_count + r.rejection_count) > 0
         THEN ROUND(r.use_count::numeric / (r.use_count + r.rejection_count), 2)
         ELSE NULL END AS acceptance_rate,
    r.confidence
FROM recon_rule r
WHERE r.source = 'smart';

COMMENT ON VIEW smart_recon_stats IS
    'Reporting view: smart reconciliation effectiveness per rule (REC-038d).';
