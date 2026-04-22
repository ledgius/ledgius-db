-- Spec references: R-0062, A-0040, A-0041, T-0029.
--
-- V1.46 — Asset register (fixed-asset primary metadata)
--
-- Primary metadata table for fixed assets per R-0062 AST-001. Holds the
-- asset's name, cost, depreciation method/life, current carrying value,
-- resolved GL accounts, state, and linkage to source documents (bill +
-- posted transactions). All monetary truth remains in acc_trans per
-- A-0009 — asset_register is a lens + driver for the posting engine,
-- not a second source of truth.
--
-- Lifecycle states per A-0040:
--   draft              — captured but no GL posted (rare, wizard flow)
--   active             — on the books, depreciating
--   fully_depreciated  — book_value reached residual, no further dep accrues
--   disposed           — sold/scrapped/donated/traded-in, disposal journal posted
--   archived           — disposed and past retention window (typically 7y)
--
-- `bas_label` is intentionally NOT a column on acc_trans (see V1.48
-- comments). BAS labels are derived by the BAS extraction layer (A-0042
-- forthcoming) from source tax documents + tax codes, not tagged here.

CREATE TABLE IF NOT EXISTS asset_register (
    id                               UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- identity + classification
    name                             TEXT NOT NULL,
    description                      TEXT,
    category_id                      UUID NOT NULL REFERENCES asset_category(id) ON DELETE RESTRICT,

    -- acquisition cost (ex GST); GST amount carried separately for audit +
    -- reconciliation with the bill (if bill-linked)
    purchase_date                    DATE NOT NULL,
    cost_ex_gst                      NUMERIC(20, 2) NOT NULL CHECK (cost_ex_gst > 0),
    gst_amount                       NUMERIC(20, 2) NOT NULL DEFAULT 0 CHECK (gst_amount >= 0),

    -- depreciation inputs
    useful_life_years                INTEGER CHECK (
        useful_life_years IS NULL
        OR useful_life_years >= 1
    ),
    residual_value                   NUMERIC(20, 2) NOT NULL DEFAULT 0 CHECK (residual_value >= 0),
    depreciation_method              TEXT NOT NULL CHECK (
        depreciation_method IN ('straight_line', 'diminishing_value', 'instant_writeoff')
    ),
    accumulated_depreciation         NUMERIC(20, 2) NOT NULL DEFAULT 0 CHECK (accumulated_depreciation >= 0),

    -- motor-vehicle business-use split (ledger-level only — not a tax determination)
    business_use_pct                 NUMERIC(5, 2) CHECK (
        business_use_pct IS NULL
        OR (business_use_pct >= 0 AND business_use_pct <= 100)
    ),

    -- lifecycle state
    status                           TEXT NOT NULL DEFAULT 'active' CHECK (
        status IN ('draft', 'active', 'fully_depreciated', 'disposed', 'archived')
    ),

    -- resolved GL accounts (copied from category defaults at acquisition; may be overridden per-asset)
    capital_account_id               INTEGER REFERENCES account(id) ON DELETE RESTRICT,
    accum_depreciation_account_id    INTEGER REFERENCES account(id) ON DELETE RESTRICT,
    depreciation_expense_account_id  INTEGER REFERENCES account(id) ON DELETE RESTRICT,

    -- source document linkage (all optional depending on entry mode)
    supplier_entity_id               INTEGER REFERENCES entity(id) ON DELETE SET NULL,
    linked_bill_id                   INTEGER REFERENCES transactions(id) ON DELETE SET NULL,

    -- posted transaction references (set by the acquisition / disposal commands)
    acquisition_transaction_id       INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
    disposal_transaction_id          INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
    disposal_date                    DATE,

    -- AASB 108 estimate-change audit trail (ChangeDepreciationEstimate command
    -- appends an entry here — see A-0040 §3, R-0062 AST-015b).
    -- Shape per row: {"field":"useful_life_years","old":5,"new":7,"effective_from":"2026-07-01","reason":"..."}
    estimate_changes                 JSONB NOT NULL DEFAULT '[]'::jsonb,

    -- correction linkage (A-0041 §8 — reclass or prior-period restatement)
    correction_id                    UUID,

    created_at                       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                       TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- integrity constraints
    CONSTRAINT asset_register_residual_le_cost CHECK (residual_value <= cost_ex_gst),
    CONSTRAINT asset_register_useful_life_required CHECK (
        depreciation_method = 'instant_writeoff'
        OR useful_life_years IS NOT NULL
    ),
    CONSTRAINT asset_register_disposal_date_after_purchase CHECK (
        disposal_date IS NULL OR disposal_date >= purchase_date
    ),
    CONSTRAINT asset_register_disposal_requires_txn CHECK (
        (status = 'disposed' AND disposal_transaction_id IS NOT NULL AND disposal_date IS NOT NULL)
        OR status <> 'disposed'
    )
);

COMMENT ON TABLE  asset_register IS 'Fixed-asset primary metadata with depreciation inputs and lifecycle state. R-0062 AST-001. Ledger truth lives in acc_trans — this is the lens + driver for the posting engine.';
COMMENT ON COLUMN asset_register.name IS 'Human-readable asset name (e.g. "Dell Latitude 5540 — Matt").';
COMMENT ON COLUMN asset_register.category_id IS 'FK to asset_category. Drives GL account defaults + motor-vehicle flagging.';
COMMENT ON COLUMN asset_register.cost_ex_gst IS 'Purchase cost exclusive of GST. Must be > 0. Used as the Dr amount on the capital account at acquisition (A-0041 §2 row 1).';
COMMENT ON COLUMN asset_register.gst_amount IS 'GST component of the purchase (>= 0). Zero for GST-free suppliers / overseas / GST-not-applicable.';
COMMENT ON COLUMN asset_register.useful_life_years IS 'Useful life in years. NULL only when depreciation_method=instant_writeoff.';
COMMENT ON COLUMN asset_register.residual_value IS 'Estimated salvage value at end of useful life. Depreciation floors at this — book_value never goes below residual.';
COMMENT ON COLUMN asset_register.depreciation_method IS 'Per-asset method: straight_line, diminishing_value, instant_writeoff. R-0062 AST-003.';
COMMENT ON COLUMN asset_register.accumulated_depreciation IS 'Running total of periodic depreciation posted against the asset. Maintained by depreciation run + reversal commands. Reconciliation job verifies this matches the sum of tagged acc_trans rows (A-0040 I3).';
COMMENT ON COLUMN asset_register.business_use_pct IS 'Motor-vehicle business-use percentage (0–100). Null for non-vehicles. Drives the ledger-level deductible/non-deductible split on dep expense rows (A-0041 §4); NOT a tax determination — see R-0062 AST-014 and the tax layer R-0073.';
COMMENT ON COLUMN asset_register.status IS 'Lifecycle state per A-0040: draft | active | fully_depreciated | disposed | archived.';
COMMENT ON COLUMN asset_register.capital_account_id IS 'Balance-sheet capital account for this asset. Debited on acquisition, credited on disposal.';
COMMENT ON COLUMN asset_register.accum_depreciation_account_id IS 'Accumulated-depreciation contra-asset account. Credited on periodic depreciation runs, debited on disposal to clear.';
COMMENT ON COLUMN asset_register.depreciation_expense_account_id IS 'P&L depreciation-expense account. Debited on periodic depreciation runs.';
COMMENT ON COLUMN asset_register.linked_bill_id IS 'Optional link to the source AP bill (via transactions.id). Present for bill-create and bill-reclass entry modes.';
COMMENT ON COLUMN asset_register.acquisition_transaction_id IS 'Parent transaction id of the posted acquisition journal (A-0041 §2 or §3).';
COMMENT ON COLUMN asset_register.disposal_transaction_id IS 'Parent transaction id of the posted disposal journal (A-0041 §6). Null until disposed.';
COMMENT ON COLUMN asset_register.estimate_changes IS 'AASB 108 prospective estimate-change history. Each entry: {field, old, new, effective_from, reason}. Populated by the ChangeDepreciationEstimate command (A-0040 §3, R-0062 AST-015b).';
COMMENT ON COLUMN asset_register.correction_id IS 'Groups the current row with the reversal+repost pair when the asset has been reclassified in-period. See A-0041 §8.2.';

CREATE INDEX IF NOT EXISTS idx_asset_register_status           ON asset_register(status);
CREATE INDEX IF NOT EXISTS idx_asset_register_category         ON asset_register(category_id);
CREATE INDEX IF NOT EXISTS idx_asset_register_purchase_date    ON asset_register(purchase_date);
CREATE INDEX IF NOT EXISTS idx_asset_register_correction_id    ON asset_register(correction_id) WHERE correction_id IS NOT NULL;
