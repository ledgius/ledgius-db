-- Stripe Connect columns on tenants for payment processing.
-- Spec references: R-0050 AC-6, A-0026.

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS stripe_connect_account_id TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS stripe_connect_type TEXT
    CHECK (stripe_connect_type IN ('express', 'standard'));
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS stripe_connect_onboarded BOOLEAN DEFAULT false;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS stripe_connect_charges_enabled BOOLEAN DEFAULT false;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS stripe_connect_payouts_enabled BOOLEAN DEFAULT false;

COMMENT ON COLUMN tenants.stripe_connect_account_id IS 'Stripe Connect account ID (acct_xxx). Set after onboarding.';
COMMENT ON COLUMN tenants.stripe_connect_type IS 'express = Ledgius platform collects, standard = direct to user Stripe account.';
COMMENT ON COLUMN tenants.stripe_connect_onboarded IS 'True when Stripe onboarding is complete and account is verified.';
COMMENT ON COLUMN tenants.stripe_connect_charges_enabled IS 'True when the connected account can accept charges.';
COMMENT ON COLUMN tenants.stripe_connect_payouts_enabled IS 'True when the connected account can receive payouts.';
