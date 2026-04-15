-- Spec references: R-0040 (audit trail), R-0049 (bank feeds use case),
--                   R-0054 (LSMB migration tracking).
--
-- payment_vendor_link — Ledgius-shape override table that lets us attribute
-- a payment transaction to a vendor (entity_credit_account) when the LSMB
-- data model can't.
--
-- Use cases (per architecture discussion):
--   1. Legacy payments imported before vendors were set up (parity test data,
--      MYOB pre-import payments)
--   2. Bank-feed transactions reconciled to a payment without a known vendor
--      (R-0049)
--   3. Manual GL journal entries that bypass the AP allocation flow
--   4. Re-attribution of an originally-mis-attributed payment
--
-- Why an override table rather than touching LSMB tables:
--   - Pure metadata enrichment — GL is unchanged
--   - One row per payment (PRIMARY KEY on trans_id), preventing accidental
--     double-attribution
--   - Aligns with R-0054 architectural direction: all new logic in Go,
--     LSMB tables are quarantined and migrated out over time
--
-- The ListPayments query coalesces vendor attribution from two sources:
--   a) LSMB-derived: payment.acc_trans.open_item_id → ap.open_item_id
--      → entity_credit_account (the canonical path for normal payments
--      that allocate against bills via the AP API)
--   b) Override: this table — used when (a) is null
--
-- The attach-vendor endpoint refuses if a vendor is already attributed
-- via either source, so this table doesn't drift from LSMB-derived truth.

CREATE TABLE IF NOT EXISTS payment_vendor_link (
    trans_id              INT PRIMARY KEY REFERENCES transactions(id) ON DELETE CASCADE,
    entity_credit_account INT NOT NULL REFERENCES entity_credit_account(id),
    attributed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    attributed_by         UUID NULL,
    notes                 TEXT
);

COMMENT ON TABLE payment_vendor_link IS
    'Ledgius-shape vendor attribution for payment transactions whose LSMB-side ' ||
    'allocation linkage (acc_trans.open_item_id → ap) is missing. Pure metadata ' ||
    'enrichment — GL postings are not touched. Used by ListPayments query as a ' ||
    'fallback when LSMB-derived vendor is NULL.';

COMMENT ON COLUMN payment_vendor_link.trans_id IS
    'The payment transaction this attribution applies to. PRIMARY KEY guarantees ' ||
    'one attribution per payment.';

COMMENT ON COLUMN payment_vendor_link.entity_credit_account IS
    'The vendor (entity_credit_account row) this payment is attributed to.';

COMMENT ON COLUMN payment_vendor_link.attributed_by IS
    'User who created the attribution. NULL for system-driven attribution ' ||
    '(e.g. future bank-feed auto-attribution).';

CREATE INDEX IF NOT EXISTS idx_payment_vendor_link_eca
    ON payment_vendor_link(entity_credit_account);
