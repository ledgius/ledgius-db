-- Spec references: R-0068.
--
-- V1.06 — Tenant branding, contact, and billing address fields.
--
-- Trading name + logo for app header and invoices.
-- Contact details + billing address appear on invoices.

ALTER TABLE tenants
    ADD COLUMN IF NOT EXISTS trading_name TEXT,
    ADD COLUMN IF NOT EXISTS logo_path TEXT,
    ADD COLUMN IF NOT EXISTS logo_type TEXT,
    ADD COLUMN IF NOT EXISTS contact_email TEXT,
    ADD COLUMN IF NOT EXISTS contact_phone TEXT,
    ADD COLUMN IF NOT EXISTS contact_website TEXT,
    ADD COLUMN IF NOT EXISTS billing_street TEXT,
    ADD COLUMN IF NOT EXISTS billing_city TEXT,
    ADD COLUMN IF NOT EXISTS billing_state TEXT,
    ADD COLUMN IF NOT EXISTS billing_postcode TEXT,
    ADD COLUMN IF NOT EXISTS billing_country TEXT DEFAULT 'Australia';

COMMENT ON COLUMN tenants.trading_name IS 'Trading name displayed in app header and on invoices. May differ from legal/display name.';
COMMENT ON COLUMN tenants.logo_path IS 'Path to tenant logo file on data volume. Relative to /data/{slug}/.';
COMMENT ON COLUMN tenants.logo_type IS 'Logo file type: svg (preferred), png, jpeg, webp.';
COMMENT ON COLUMN tenants.contact_email IS 'Business contact email. Appears on invoices.';
COMMENT ON COLUMN tenants.contact_phone IS 'Business phone. Appears on invoices.';
COMMENT ON COLUMN tenants.contact_website IS 'Business website URL.';
COMMENT ON COLUMN tenants.billing_street IS 'Billing/registered address — street line.';
COMMENT ON COLUMN tenants.billing_city IS 'Billing address — city/suburb.';
COMMENT ON COLUMN tenants.billing_state IS 'Billing address — state (e.g. VIC, NSW).';
COMMENT ON COLUMN tenants.billing_postcode IS 'Billing address — postcode.';
COMMENT ON COLUMN tenants.billing_country IS 'Billing address — country. Default: Australia.';
