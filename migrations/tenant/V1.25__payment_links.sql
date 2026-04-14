-- Payment links for invoices — Stripe payment link tracking.
-- Spec references: R-0050 AC-6, A-0026.

CREATE TABLE IF NOT EXISTS payment_link (
    id                  SERIAL PRIMARY KEY,
    invoice_trans_id    INT NOT NULL,
    stripe_session_id   TEXT,
    stripe_payment_link TEXT,
    amount              NUMERIC NOT NULL,
    currency            TEXT NOT NULL DEFAULT 'AUD',
    status              TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'expired', 'cancelled')),
    paid_at             TIMESTAMPTZ,
    stripe_payment_intent TEXT,
    customer_email      TEXT,
    url                 TEXT NOT NULL,
    expires_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE payment_link IS 'Stripe payment links generated for invoices. Tracks payment status via webhooks.';
COMMENT ON COLUMN payment_link.invoice_trans_id IS 'The AR transaction ID this payment link is for.';
COMMENT ON COLUMN payment_link.url IS 'The Stripe Checkout URL the customer clicks to pay.';

CREATE INDEX IF NOT EXISTS idx_payment_link_invoice ON payment_link(invoice_trans_id);
CREATE INDEX IF NOT EXISTS idx_payment_link_session ON payment_link(stripe_session_id) WHERE stripe_session_id IS NOT NULL;
