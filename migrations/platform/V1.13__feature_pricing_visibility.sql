-- Spec references: R-0069 (PP-020).
--
-- V1.13 — Add visible_on_pricing flag to features table.
-- Some features are "accounting 101" (chart of accounts, contact management)
-- and should be enabled but not listed on the pricing page cards.

ALTER TABLE features
    ADD COLUMN IF NOT EXISTS visible_on_pricing BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN features.visible_on_pricing IS
    'Whether this feature appears on pricing page cards. '
    'Features like Chart of Accounts are always enabled but not worth listing. '
    'Set to false to enable the feature without cluttering the pricing display.';

-- Hide obvious accounting features from pricing cards.
UPDATE features SET visible_on_pricing = false WHERE slug IN (
    'chart_of_accounts',
    'contacts',
    'mileage',
    'journal_entries',
    'audit_trail',
    'email_support'
);
