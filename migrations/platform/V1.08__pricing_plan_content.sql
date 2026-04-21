-- Spec references: R-0069 (PP-023, PP-040).
--
-- V1.08 — Regional pricing content for the public pricing page.
-- Separates display content from plan identity and commercial terms.

-- =============================================================================
-- 1. Pricing plan content table
-- =============================================================================

CREATE TABLE IF NOT EXISTS pricing_plan_content (
    id                  SERIAL PRIMARY KEY,
    plan_id             INT NOT NULL REFERENCES pricing_plans(id),
    region              TEXT NOT NULL DEFAULT 'au',
    currency            TEXT NOT NULL DEFAULT 'AUD',
    currency_symbol     TEXT NOT NULL DEFAULT 'A$',
    monthly_price       NUMERIC(10,2) NOT NULL,
    annual_price        NUMERIC(10,2) NOT NULL,
    tax_note            TEXT DEFAULT 'Prices include GST',
    tagline             TEXT,
    feature_description TEXT,
    feature_bullets     JSONB DEFAULT '[]',
    competitive_context TEXT,
    cta_text            TEXT DEFAULT 'Start Free Trial',
    cta_url             TEXT DEFAULT '/signup',
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (plan_id, region)
);

COMMENT ON TABLE pricing_plan_content IS
    'Regional pricing content for the public pricing page. '
    'Keyed by (plan_id, region) — same plan can have different content per country.';

-- =============================================================================
-- 2. Seed AU pricing data
-- =============================================================================

-- First ensure the plans exist
INSERT INTO pricing_plans (slug, name, description, price_monthly, price_annually, sort_order, is_popular, max_users, status)
VALUES
    ('starter', 'Starter', 'For sole traders and owner-operators', 19, 190, 1, false, 1, 'active'),
    ('business', 'Business', 'For 1–5 employee service businesses', 39, 390, 2, true, 99, 'active'),
    ('growth', 'Growth', 'For growing service teams', 69, 690, 3, false, 99, 'active'),
    ('partner', 'Ledgius Partner', 'Free practice console for accountants and bookkeepers', 0, 0, 4, false, 99, 'active')
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price_monthly = EXCLUDED.price_monthly,
    price_annually = EXCLUDED.price_annually,
    sort_order = EXCLUDED.sort_order,
    is_popular = EXCLUDED.is_popular,
    max_users = EXCLUDED.max_users,
    status = EXCLUDED.status;

-- Now seed the AU content
INSERT INTO pricing_plan_content (plan_id, region, currency, currency_symbol, monthly_price, annual_price, tax_note, tagline, feature_description, feature_bullets, competitive_context, cta_text, cta_url)
VALUES
    -- Starter
    ((SELECT id FROM pricing_plans WHERE slug = 'starter'), 'au', 'AUD', 'A$', 19, 190, 'Prices include GST',
     'For sole traders and owner-operators',
     'Everything you need to run your books. Unlimited quotes and invoices, bills, receipt capture, mileage tracking, GST/BAS reporting, bank reconciliation, contact management, payment links, and full Xero/MYOB/QuickBooks import-export.',
     '[{"label": "Unlimited quotes & invoices", "included": true}, {"label": "Bills & receipt capture", "included": true}, {"label": "GST/BAS reporting", "included": true}, {"label": "2 bank feeds + reconciliation", "included": true}, {"label": "Contact management", "included": true}, {"label": "Payment links", "included": true}, {"label": "Xero/MYOB/QuickBooks import-export", "included": true}, {"label": "Mileage tracking", "included": true}, {"label": "1 owner seat + free advisor access", "included": true}, {"label": "Payroll & STP", "included": false}, {"label": "Multi-currency", "included": false}, {"label": "API access", "included": false}]',
     'Sits below Xero Ignite, QuickBooks'' A$33 entry point, MYOB Business Lite''s effective A$26.25/month annual price, and Reckon Core''s A$24/month.',
     'Start Free Trial', '/signup'),

    -- Business
    ((SELECT id FROM pricing_plans WHERE slug = 'business'), 'au', 'AUD', 'A$', 39, 390, 'Prices include GST',
     'For 1–5 employee service businesses',
     'Everything in Starter plus the tools your team needs. Unlimited internal users, free accountant/bookkeeper access, AR/AP workflows, recurring invoices and bills, approvals, fixed assets, liability tracking, full audit trail, and advanced reporting.',
     '[{"label": "Everything in Starter", "included": true}, {"label": "Unlimited internal users", "included": true}, {"label": "Free accountant/bookkeeper access", "included": true}, {"label": "AR/AP workflows", "included": true}, {"label": "Recurring invoices & bills", "included": true}, {"label": "Approvals workflow", "included": true}, {"label": "Fixed assets & depreciation", "included": true}, {"label": "Liability tracking", "included": true}, {"label": "5 bank feeds", "included": true}, {"label": "Job/profit tags", "included": true}, {"label": "Audit trail", "included": true}, {"label": "Advanced reporting", "included": true}, {"label": "Payroll & STP (up to 5 employees)", "included": true}, {"label": "API access", "included": false}]',
     'Undercuts MYOB Business Pro, QuickBooks Essentials, and Xero Grow by a meaningful margin.',
     'Start Free Trial', '/signup'),

    -- Growth
    ((SELECT id FROM pricing_plans WHERE slug = 'growth'), 'au', 'AUD', 'A$', 69, 690, 'Prices include GST',
     'For growing service teams',
     'Everything in Business plus advanced capabilities for scaling teams. Advanced permissions, project profitability tracking, API/webhooks for integrations, cash-flow forecasting, priority support, and multi-entity roll-up as an add-on.',
     '[{"label": "Everything in Business", "included": true}, {"label": "Advanced permissions & roles", "included": true}, {"label": "Project profitability", "included": true}, {"label": "API & webhooks", "included": true}, {"label": "Cash-flow forecasting", "included": true}, {"label": "Priority support", "included": true}, {"label": "Unlimited bank feeds", "included": true}, {"label": "Unlimited payroll & STP", "included": true}, {"label": "Multi-currency", "included": true}, {"label": "Multi-entity roll-up (add-on)", "included": true}, {"label": "Custom report builder", "included": true}]',
     'Still comes in below Xero Comprehensive and below QuickBooks Plus and Advanced.',
     'Start Free Trial', '/signup'),

    -- Partner
    ((SELECT id FROM pricing_plans WHERE slug = 'partner'), 'au', 'AUD', 'A$', 0, 0, '',
     'Free practice console for accountants and bookkeepers',
     'Free practice console to manage all your Ledgius clients. Partner Compliance file at A$9/client/month for partner-managed micro clients who only need bank feeds, GST/BAS, coding and reports — not invoicing or payments. Free archive/read-only client file included.',
     '[{"label": "Free practice console", "included": true}, {"label": "Manage all Ledgius clients", "included": true}, {"label": "Partner Compliance file A$9/client/mo", "included": true}, {"label": "Bank feeds + GST/BAS + coding", "included": true}, {"label": "Free archive/read-only files", "included": true}, {"label": "Client onboarding tools", "included": true}, {"label": "Bulk actions across clients", "included": true}]',
     'Xero''s partner program is free with 250,000+ accountants. Ledgius needs its own partner wedge rather than treating advisors as an afterthought.',
     'Join Partner Program', '/partner')
ON CONFLICT (plan_id, region) DO UPDATE SET
    monthly_price = EXCLUDED.monthly_price,
    annual_price = EXCLUDED.annual_price,
    tagline = EXCLUDED.tagline,
    feature_description = EXCLUDED.feature_description,
    feature_bullets = EXCLUDED.feature_bullets,
    competitive_context = EXCLUDED.competitive_context,
    cta_text = EXCLUDED.cta_text,
    cta_url = EXCLUDED.cta_url,
    updated_at = now();
