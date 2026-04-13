-- Spec references: R-0050, A-0026.
-- Quotes table for mobile app quote creation and lifecycle management.

CREATE TABLE IF NOT EXISTS quote (
    id                      SERIAL PRIMARY KEY,
    quote_number            TEXT NOT NULL,
    entity_credit_account   INT NOT NULL,
    quote_date              DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until             DATE,
    status                  TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'sent', 'accepted', 'rejected', 'expired', 'converted')),
    subtotal                NUMERIC NOT NULL DEFAULT 0,
    tax_total               NUMERIC NOT NULL DEFAULT 0,
    total                   NUMERIC NOT NULL DEFAULT 0,
    notes                   TEXT,
    converted_invoice_id    INT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE quote IS 'Quotes/estimates sent to customers before invoicing. Can be converted to invoices on acceptance.';
COMMENT ON COLUMN quote.entity_credit_account IS 'FK to entity_credit_account — the customer this quote is for';
COMMENT ON COLUMN quote.converted_invoice_id IS 'If converted to invoice, the AR transaction ID';

CREATE INDEX IF NOT EXISTS idx_quote_status ON quote(status);
CREATE INDEX IF NOT EXISTS idx_quote_customer ON quote(entity_credit_account);

CREATE TABLE IF NOT EXISTS quote_line (
    id              SERIAL PRIMARY KEY,
    quote_id        INT NOT NULL REFERENCES quote(id) ON DELETE CASCADE,
    description     TEXT NOT NULL,
    quantity        NUMERIC NOT NULL DEFAULT 1,
    unit_price      NUMERIC NOT NULL,
    tax_code_id     INT,
    line_total      NUMERIC NOT NULL,
    sort_order      INT NOT NULL DEFAULT 0
);

COMMENT ON TABLE quote_line IS 'Line items on a quote. Each line has description, quantity, unit price, and optional tax code.';

CREATE INDEX IF NOT EXISTS idx_quote_line_quote ON quote_line(quote_id);
