-- Spec references: A-0021.
--
-- V1.06 — Products and Tax Codes (DDL only)
--
-- Creates tables for the configurable tax code registry and the
-- products/services catalogue. Seed data is in R__seed_tax_codes.sql.
--
--   tax_code — configurable tax codes with rates (replaces hardcoded 10% GST)
--   product  — products/services catalogue for invoice and bill line items

-- =============================================================================
-- 1. Tax Codes
-- =============================================================================

CREATE TABLE IF NOT EXISTS tax_code (
    id               SERIAL PRIMARY KEY,
    code             TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    description      TEXT NULL,
    rate             NUMERIC(7,4) NOT NULL DEFAULT 0.0000,
    jurisdiction     TEXT NOT NULL DEFAULT 'AU',
    tax_type         TEXT NOT NULL DEFAULT 'gst',
    chart_account_id INT NULL REFERENCES account(id),
    effective_from   DATE NOT NULL DEFAULT '2000-01-01',
    effective_to     DATE NULL,
    active           BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE tax_code IS 'Configurable tax codes with rates and linked GL accounts. Jurisdiction-aware for multi-country support.';
COMMENT ON COLUMN tax_code.code IS 'Short code, e.g. GST, FRE, INP, EXP, N-T';
COMMENT ON COLUMN tax_code.rate IS 'Tax rate as decimal, e.g. 0.1000 for 10%';
COMMENT ON COLUMN tax_code.tax_type IS 'gst, payg, fbt, none';
COMMENT ON COLUMN tax_code.chart_account_id IS 'GL account for tax collected (sales) or tax paid (purchases)';

CREATE INDEX IF NOT EXISTS idx_tax_code_active ON tax_code(active, jurisdiction);

-- =============================================================================
-- 2. Products / Services Catalogue
-- =============================================================================

CREATE TABLE IF NOT EXISTS product (
    id               SERIAL PRIMARY KEY,
    sku              TEXT NULL UNIQUE,
    name             TEXT NOT NULL,
    description      TEXT NULL,
    product_type     TEXT NOT NULL DEFAULT 'service'
        CHECK (product_type IN ('product', 'service', 'overhead')),
    unit             TEXT NULL,
    sell_price       NUMERIC NOT NULL DEFAULT 0,
    buy_price        NUMERIC NOT NULL DEFAULT 0,
    sell_tax_code_id INT NULL REFERENCES tax_code(id),
    buy_tax_code_id  INT NULL REFERENCES tax_code(id),
    income_account_id INT NULL REFERENCES account(id),
    expense_account_id INT NULL REFERENCES account(id),
    active           BOOLEAN NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE product IS 'Product and service catalogue for invoice/bill line items';
COMMENT ON COLUMN product.product_type IS 'product (physical goods), service (labour/consulting), overhead (internal cost)';
COMMENT ON COLUMN product.sell_tax_code_id IS 'Default tax code when selling this product';
COMMENT ON COLUMN product.buy_tax_code_id IS 'Default tax code when purchasing this product';
COMMENT ON COLUMN product.income_account_id IS 'Default revenue account for sales';
COMMENT ON COLUMN product.expense_account_id IS 'Default expense account for purchases';

CREATE INDEX IF NOT EXISTS idx_product_active ON product(active);
CREATE INDEX IF NOT EXISTS idx_product_type ON product(product_type);
CREATE INDEX IF NOT EXISTS idx_product_name ON product(name);
