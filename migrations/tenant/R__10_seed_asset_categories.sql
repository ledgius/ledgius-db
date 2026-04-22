-- Spec references: R-0062, T-0029.
--
-- R__10_seed_asset_categories.sql — Fixed-asset category seed data (repeatable).
--
-- Seeds the five categories from R-0062 AST-002 with default GL accounts
-- resolved from the Australian chart of accounts seeded by
-- R__02_seed_chart_of_accounts_au.sql. The AU COA covers most categories
-- directly; Office Equipment and Furniture & Fittings share the 1830/1835
-- Furniture & Equipment pair (tenants may add discrete accounts later).
--
-- Idempotent: ON CONFLICT (code) DO NOTHING. UPDATE statements for account
-- links are conditional on NULL so it is safe to re-run even after the COA
-- seed has been refreshed.

INSERT INTO asset_category (code, name, active)
VALUES
    ('plant_equipment',    'Plant & Equipment',     TRUE),
    ('motor_vehicles',     'Motor Vehicles',        TRUE),
    ('office_equipment',   'Office Equipment',      TRUE),
    ('furniture_fittings', 'Furniture & Fittings',  TRUE),
    ('it_equipment',       'IT Equipment',          TRUE)
ON CONFLICT (code) DO NOTHING;

-- Plant & Equipment  → 1860 capital / 1865 accum / 6080 dep expense
UPDATE asset_category SET
    default_capital_account_id              = (SELECT id FROM account WHERE accno = '1860' LIMIT 1),
    default_accum_depr_account_id           = (SELECT id FROM account WHERE accno = '1865' LIMIT 1),
    default_depreciation_expense_account_id = (SELECT id FROM account WHERE accno = '6080' LIMIT 1),
    updated_at                              = now()
WHERE code = 'plant_equipment'
  AND (default_capital_account_id IS NULL OR default_accum_depr_account_id IS NULL OR default_depreciation_expense_account_id IS NULL);

-- Motor Vehicles  → 1840 / 1845 / 6080
UPDATE asset_category SET
    default_capital_account_id              = (SELECT id FROM account WHERE accno = '1840' LIMIT 1),
    default_accum_depr_account_id           = (SELECT id FROM account WHERE accno = '1845' LIMIT 1),
    default_depreciation_expense_account_id = (SELECT id FROM account WHERE accno = '6080' LIMIT 1),
    updated_at                              = now()
WHERE code = 'motor_vehicles'
  AND (default_capital_account_id IS NULL OR default_accum_depr_account_id IS NULL OR default_depreciation_expense_account_id IS NULL);

-- Office Equipment  → 1830 / 1835 / 6080 (shared with Furniture & Fittings)
UPDATE asset_category SET
    default_capital_account_id              = (SELECT id FROM account WHERE accno = '1830' LIMIT 1),
    default_accum_depr_account_id           = (SELECT id FROM account WHERE accno = '1835' LIMIT 1),
    default_depreciation_expense_account_id = (SELECT id FROM account WHERE accno = '6080' LIMIT 1),
    updated_at                              = now()
WHERE code = 'office_equipment'
  AND (default_capital_account_id IS NULL OR default_accum_depr_account_id IS NULL OR default_depreciation_expense_account_id IS NULL);

-- Furniture & Fittings  → 1830 / 1835 / 6080
UPDATE asset_category SET
    default_capital_account_id              = (SELECT id FROM account WHERE accno = '1830' LIMIT 1),
    default_accum_depr_account_id           = (SELECT id FROM account WHERE accno = '1835' LIMIT 1),
    default_depreciation_expense_account_id = (SELECT id FROM account WHERE accno = '6080' LIMIT 1),
    updated_at                              = now()
WHERE code = 'furniture_fittings'
  AND (default_capital_account_id IS NULL OR default_accum_depr_account_id IS NULL OR default_depreciation_expense_account_id IS NULL);

-- IT Equipment  → 1850 (Computer Equipment) / 1855 / 6080
UPDATE asset_category SET
    default_capital_account_id              = (SELECT id FROM account WHERE accno = '1850' LIMIT 1),
    default_accum_depr_account_id           = (SELECT id FROM account WHERE accno = '1855' LIMIT 1),
    default_depreciation_expense_account_id = (SELECT id FROM account WHERE accno = '6080' LIMIT 1),
    updated_at                              = now()
WHERE code = 'it_equipment'
  AND (default_capital_account_id IS NULL OR default_accum_depr_account_id IS NULL OR default_depreciation_expense_account_id IS NULL);
