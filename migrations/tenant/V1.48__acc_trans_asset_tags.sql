-- Spec references: R-0062, A-0040, A-0041, T-0029.
--
-- V1.48 — Asset-context tags on acc_trans
--
-- Adds nullable metadata columns to acc_trans so asset-originated rows
-- can be identified + filtered without joining through transactions
-- every time. Consumers:
--
--   asset_id           — dashboard queries, per-asset history, reconciliation
--   run_id             — period-close queries on depreciation runs
--   correction_id      — audit of same-period reclass (A-0041 §8.2)
--   restatement_id     — audit of AASB 108 prior-period restatement (§8.4)
--   reclass_from_bill  — BAS extractor signal: "ignore for BAS — original bill already counted" (§3)
--   deductible         — ledger-level deductibility split for motor-vehicle
--                        business-use % (A-0041 §4). NOT a tax determination.
--
-- INTENTIONALLY NOT ADDED: bas_label. The earlier draft of A-0041 proposed
-- tagging G10 / 1A directly on acc_trans rows — this was removed in PR review
-- because (a) bill-reclassification rows would double-count G10 (the original
-- bill is already in BAS scope), and (b) BAS cash-vs-accrual reporting basis
-- and the $1,000 G10/G11 threshold are reporting-layer concerns. BAS labels
-- (G1 / G10 / G11 / 1A / 1B) are derived by the BAS extraction layer
-- (A-0042 forthcoming) by joining GL rows to source tax documents + tax codes.
--
-- Forward-only migration. All columns nullable; existing rows unaffected.

ALTER TABLE acc_trans
    ADD COLUMN IF NOT EXISTS asset_id          UUID,
    ADD COLUMN IF NOT EXISTS run_id            UUID,
    ADD COLUMN IF NOT EXISTS correction_id     UUID,
    ADD COLUMN IF NOT EXISTS restatement_id    UUID,
    ADD COLUMN IF NOT EXISTS reclass_from_bill INTEGER,
    ADD COLUMN IF NOT EXISTS deductible        BOOLEAN;

COMMENT ON COLUMN acc_trans.asset_id IS 'If set, this acc_trans row belongs to the asset with this id (FK to asset_register.id). Populated on acquisition, depreciation, disposal, correction. R-0062 AST-013 / A-0041 §10.';
COMMENT ON COLUMN acc_trans.run_id IS 'If set, this row belongs to a depreciation run (FK to depreciation_run.id, future table). Enables per-run queries and reversal.';
COMMENT ON COLUMN acc_trans.correction_id IS 'Groups reversal + fresh-repost rows from a same-period asset reclassification (A-0041 §8.2).';
COMMENT ON COLUMN acc_trans.restatement_id IS 'Tags rows posted by AASB 108 prior-period restatement (A-0041 §8.4). Rows are in the current period; restatement_period is captured in the transactions row.';
COMMENT ON COLUMN acc_trans.reclass_from_bill IS 'On bill-reclassification rows (A-0041 §3), the source bill transaction.id. Signals to the BAS extractor to skip these rows — original bill is already in BAS scope.';
COMMENT ON COLUMN acc_trans.deductible IS 'Ledger-level deductibility split for motor-vehicle depreciation expense rows (A-0041 §4). NOT a tax determination — tax deductibility is computed by the tax layer (R-0073) using entity type + FBT context.';

CREATE INDEX IF NOT EXISTS idx_acc_trans_asset_id ON acc_trans(asset_id) WHERE asset_id IS NOT NULL;
