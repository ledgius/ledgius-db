-- Products/services catalogue and configurable tax codes.
-- These tables exist in each tenant database.

-- =============================================================================
-- 1. Tax Codes (replaces hardcoded 10% GST)
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

-- Seed Australian tax codes.
-- chart_account_id will be set after account lookup.
INSERT INTO tax_code (code, name, description, rate, jurisdiction, tax_type, active)
VALUES
    ('GST', 'GST', 'Goods and Services Tax — standard rate 10%', 0.1000, 'AU', 'gst', true),
    ('FRE', 'GST-Free', 'GST-free supply (Division 38)', 0.0000, 'AU', 'gst', true),
    ('INP', 'Input Taxed', 'Input taxed supply (Division 40) — no GST, no ITC', 0.0000, 'AU', 'gst', true),
    ('EXP', 'Export', 'GST-free export supply', 0.0000, 'AU', 'gst', true),
    ('N-T', 'No Tax', 'Not subject to GST (out of scope)', 0.0000, 'AU', 'none', true),
    ('CAP', 'GST on Capital', 'GST on capital acquisitions (BAS G10)', 0.1000, 'AU', 'gst', true)
ON CONFLICT (code) DO NOTHING;

-- Link GST code to GST Collected account (2200) if it exists.
UPDATE tax_code SET chart_account_id = (
    SELECT id FROM account WHERE accno = '2200' LIMIT 1
) WHERE code = 'GST' AND chart_account_id IS NULL;

-- Link CAP code to GST Paid account (1200) if it exists.
UPDATE tax_code SET chart_account_id = (
    SELECT id FROM account WHERE accno = '1200' LIMIT 1
) WHERE code = 'CAP' AND chart_account_id IS NULL;

-- =============================================================================
-- 2. Products / Services catalogue
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
