-- Spec references: R-0062, A-0040, A-0041, T-0029.
--
-- V1.45 — Asset category (fixed-asset classification)
--
-- Tenant-configurable categories for fixed assets per R-0062 AST-002.
-- Each category carries default GL accounts (capital, accumulated
-- depreciation, depreciation expense) that acquisition flows pick up
-- automatically when the user selects a category on the Buy Asset form.
-- Explicit per-asset overrides on asset_register win; these are defaults.
--
-- Per-tenant seed data is shipped via R__10_seed_asset_categories.sql
-- (idempotent upserts on code). Tenants may add bespoke categories via
-- the admin API in future.

CREATE TABLE IF NOT EXISTS asset_category (
    id                                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                                        TEXT NOT NULL,
    name                                        TEXT NOT NULL,
    default_capital_account_id                  INTEGER REFERENCES account(id) ON DELETE RESTRICT,
    default_accum_depr_account_id               INTEGER REFERENCES account(id) ON DELETE RESTRICT,
    default_depreciation_expense_account_id     INTEGER REFERENCES account(id) ON DELETE RESTRICT,
    active                                      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT asset_category_code_unique UNIQUE (code)
);

COMMENT ON TABLE  asset_category IS 'Fixed-asset categories (Plant & Equipment, Motor Vehicles, etc.) with per-category default GL accounts. R-0062 AST-002.';
COMMENT ON COLUMN asset_category.code IS 'Machine-readable identifier (e.g. plant_equipment, motor_vehicles). Unique per tenant.';
COMMENT ON COLUMN asset_category.name IS 'Human-readable label shown in dropdowns and on the asset register.';
COMMENT ON COLUMN asset_category.default_capital_account_id IS 'Default capital (balance-sheet) account for assets of this category. Null means no default; user must pick explicitly at acquisition.';
COMMENT ON COLUMN asset_category.default_accum_depr_account_id IS 'Default accumulated-depreciation contra-asset account. Credits on every periodic depreciation run.';
COMMENT ON COLUMN asset_category.default_depreciation_expense_account_id IS 'Default depreciation-expense (P&L) account. Debits on every periodic depreciation run.';
COMMENT ON COLUMN asset_category.active IS 'False soft-deletes the category — existing assets keep using it but it no longer appears in new-asset dropdowns.';

CREATE INDEX IF NOT EXISTS idx_asset_category_active ON asset_category(active) WHERE active = TRUE;
