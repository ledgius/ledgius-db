-- Spec references: R-0069 (PP-026 through PP-040), R-0068 (PA-030).
--
-- V1.11 — Seed production features, pricing plans, plan-feature mappings,
-- plan inheritance, and AU regional content.
--
-- This is production seed data. Plans and features define the product
-- catalogue that drives the public pricing page and feature gates.

-- =============================================================================
-- 1. Pricing Plans (R-0069 PP-040)
-- =============================================================================

INSERT INTO pricing_plans (slug, name, description, price_monthly, price_annually, sort_order, is_popular, max_users, max_employees, status, badge_text)
VALUES
  ('starter',  'Starter',         'For sole traders and owner-operators',                       19,  190, 1, false,   1, NULL, 'active', NULL),
  ('business', 'Business',        'For 1–5 employee service businesses',                        39,  390, 2, true,  NULL,    5, 'active', 'Most Popular'),
  ('growth',   'Growth',          'For growing service teams',                                  69,  690, 3, false, NULL, NULL, 'active', NULL),
  ('partner',  'Ledgius Partner', 'Free practice console for accountants and bookkeepers',       0,    0, 4, false, NULL, NULL, 'active', NULL)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price_monthly = EXCLUDED.price_monthly,
  price_annually = EXCLUDED.price_annually,
  sort_order = EXCLUDED.sort_order,
  is_popular = EXCLUDED.is_popular,
  max_users = EXCLUDED.max_users,
  max_employees = EXCLUDED.max_employees,
  status = EXCLUDED.status,
  badge_text = EXCLUDED.badge_text,
  updated_at = now();

-- =============================================================================
-- 2. Plan Inheritance (R-0069 PP-026)
-- =============================================================================

UPDATE pricing_plans
SET inherits_from_plan_id = (SELECT id FROM pricing_plans WHERE slug = 'starter')
WHERE slug = 'business';

UPDATE pricing_plans
SET inherits_from_plan_id = (SELECT id FROM pricing_plans WHERE slug = 'business')
WHERE slug = 'growth';

UPDATE pricing_plans
SET inherits_from_plan_id = NULL
WHERE slug IN ('starter', 'partner');

-- =============================================================================
-- 3. Features (with markup_description for rich content)
-- =============================================================================

INSERT INTO features (slug, name, description, markup_description, category, sort_order) VALUES
  -- Core
  ('invoicing',             'Invoicing & Quotes',           'Create, send, and track invoices and quotes',
   'Create, send, and track **invoices and quotes**. Automatic payment reminders and overdue notifications.',
   'core', 1),
  ('bills',                 'Bills & Expenses',             'Record bills, receipts, and business expenses',
   'Track **bills**, capture **receipts**, and categorise expenses. Never lose a deduction.',
   'core', 2),
  ('contacts',              'Contact Management',           'Customer and vendor management with full history',
   'Manage **customers and vendors** with full transaction history, notes, and communication log.',
   'core', 3),
  ('chart_of_accounts',     'Chart of Accounts',            'Customisable chart of accounts with AU defaults',
   'Customisable **chart of accounts** pre-loaded with Australian standard categories.',
   'core', 4),
  ('mileage',               'Mileage Tracking',             'Track business mileage for ATO deductions',
   'Log **business kilometres** for ATO deductions. Automatic rate calculation.',
   'core', 5),
  ('payment_links',         'Payment Links',                'Send payment links with invoices for faster collection',
   'Embed **payment links** in invoices. Customers pay online — faster collection, less chasing.',
   'core', 6),

  -- Banking
  ('bank_feeds',            'Bank Feeds',                   'Live bank account connections for automatic imports',
   'Connect bank accounts for **automatic transaction imports**. Supported across major AU banks.',
   'banking', 10),
  ('bank_reconciliation',   'Bank Reconciliation',          'Match bank transactions to ledger entries',
   'Match bank transactions to ledger entries. Rules-based auto-matching for repeat patterns.',
   'banking', 11),

  -- Accounting
  ('multi_currency',        'Multi-Currency',               'Transact in multiple currencies with exchange rates',
   'Transact in **multiple currencies** with automatic exchange rate lookup.',
   'accounting', 20),
  ('journal_entries',       'Journal Entries',              'Manual journal entries for adjustments',
   'Manual **journal entries** with approval workflow for period-end adjustments.',
   'accounting', 21),
  ('recurring',             'Recurring Transactions',       'Automate repeating invoices, bills, and journals',
   'Schedule **recurring invoices and bills** on any frequency (weekly, monthly, quarterly, custom RRULE).',
   'accounting', 22),
  ('fixed_assets',          'Fixed Assets',                 'Asset register with depreciation schedules',
   'Full **asset register** with straight-line and diminishing-value **depreciation**.',
   'accounting', 23),
  ('liability_tracking',    'Liability Tracking',           'Track loans, leases, and other liabilities',
   'Track **loans, leases**, and other liabilities with amortisation schedules.',
   'accounting', 24),
  ('approvals',             'Approvals Workflow',           'Review and approve transactions before posting',
   'Require **approval** for bills, journals, or transactions above a threshold.',
   'accounting', 25),

  -- Payroll
  ('payroll',               'Payroll & STP',                'Process pay runs with PAYG, super, leave, and STP Phase 2 reporting',
   'Full **payroll**: PAYG withholding, super guarantee, leave accrual, and **STP Phase 2** lodgement to the ATO.',
   'payroll', 30),

  -- Compliance
  ('gst_bas',               'GST/BAS Reporting',            'Automatic GST calculation and BAS preparation',
   'Automatic **GST calculation** on every transaction. Generate and lodge your **BAS** directly.',
   'compliance', 40),
  ('audit_trail',           'Audit Trail',                  'Immutable record of all changes',
   'Every change recorded with **who, when, and why**. Nothing deleted — only reversed. Full auditability.',
   'compliance', 41),

  -- Reporting
  ('financial_reports',     'Financial Reports',            'Profit & Loss, Balance Sheet, Trial Balance, and more',
   'Standard reports: **P&L**, **Balance Sheet**, **Trial Balance**, **Cash Flow Statement**.',
   'reporting', 50),
  ('advanced_reporting',    'Advanced Reporting',           'Aged receivables/payables, job/profit tags, dashboard',
   'Aged receivables, aged payables, **job/profit tags**, and Books Health dashboard.',
   'reporting', 51),
  ('custom_reports',        'Custom Report Builder',        'Build custom reports with flexible filters',
   'Create **custom reports** with flexible filters, grouping, and export.',
   'reporting', 52),
  ('cashflow_forecast',     'Cash-Flow Forecasting',        'Predict future cash position based on scheduled transactions',
   'Predict your **future cash position** based on recurring invoices, bills, and scheduled payments.',
   'reporting', 53),
  ('project_profit',        'Project Profitability',        'Track revenue and costs per project or job',
   'Track **revenue and costs** per project or job. See which work is profitable.',
   'reporting', 54),

  -- Integrations
  ('import_export',         'Import & Export',              'Import from Xero, MYOB, QuickBooks. Export CSV, PDF.',
   'Import from **Xero, MYOB AO, QuickBooks Online**. Export in CSV, PDF, and accounting formats.',
   'integrations', 60),
  ('api_webhooks',          'API & Webhooks',               'REST API and webhook notifications for custom integrations',
   'Full **REST API** and **webhook** notifications for custom integrations and automation.',
   'integrations', 61),

  -- Permissions
  ('advanced_permissions',  'Advanced Permissions',         'Fine-grained role and permission configuration',
   'Fine-grained **role and permission** configuration. Restrict access by module, account, or action.',
   'permissions', 70),
  ('advisor_access',        'Free Advisor Access',          'Invite your accountant or bookkeeper at no extra cost',
   'Invite your **accountant or bookkeeper** with their own login — included at no extra cost.',
   'permissions', 71),
  ('unlimited_users',       'Unlimited Internal Users',     'No seat limits for your team',
   'Add as many team members as you need — **no seat limits**.',
   'permissions', 72),

  -- Support
  ('email_support',         'Email Support',                'Email support during business hours',
   'Australian-based **email support** during business hours.',
   'support', 80),
  ('priority_support',      'Priority Support',             'Priority response with dedicated account manager',
   '**Priority response** with a dedicated account manager.',
   'support', 81),

  -- Multi-entity
  ('multi_entity',          'Multi-Entity Roll-Up',         'Consolidated reporting across multiple businesses (add-on)',
   'Consolidated **reporting across multiple businesses**. Available as an add-on.',
   'multi_entity', 90)

ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  markup_description = EXCLUDED.markup_description,
  category = EXCLUDED.category,
  sort_order = EXCLUDED.sort_order;

-- =============================================================================
-- 4. Plan-Feature Mappings
-- =============================================================================

DELETE FROM plan_features;

-- Starter: core accounting for sole traders
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, CASE
    WHEN f.slug = 'bank_feeds' THEN '2'
    ELSE NULL
  END
FROM pricing_plans p, features f
WHERE p.slug = 'starter' AND f.slug IN (
  'invoicing', 'bills', 'contacts', 'chart_of_accounts', 'mileage',
  'payment_links', 'bank_feeds', 'bank_reconciliation',
  'gst_bas', 'audit_trail', 'financial_reports',
  'import_export', 'email_support'
);

-- Business: everything in Starter plus team features
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, CASE
    WHEN f.slug = 'bank_feeds' THEN '5'
    WHEN f.slug = 'payroll' THEN '5 employees'
    ELSE NULL
  END
FROM pricing_plans p, features f
WHERE p.slug = 'business' AND f.slug IN (
  'invoicing', 'bills', 'contacts', 'chart_of_accounts', 'mileage',
  'payment_links', 'bank_feeds', 'bank_reconciliation',
  'gst_bas', 'audit_trail', 'financial_reports',
  'import_export', 'email_support',
  'unlimited_users', 'advisor_access',
  'recurring', 'approvals', 'fixed_assets', 'liability_tracking',
  'journal_entries', 'payroll',
  'advanced_reporting',
  'multi_currency'
);

-- Growth: everything in Business plus advanced capabilities
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, CASE
    WHEN f.slug = 'bank_feeds' THEN 'unlimited'
    WHEN f.slug = 'payroll' THEN 'unlimited'
    ELSE NULL
  END
FROM pricing_plans p, features f
WHERE p.slug = 'growth' AND f.slug IN (
  'invoicing', 'bills', 'contacts', 'chart_of_accounts', 'mileage',
  'payment_links', 'bank_feeds', 'bank_reconciliation',
  'gst_bas', 'audit_trail', 'financial_reports',
  'import_export', 'email_support',
  'unlimited_users', 'advisor_access',
  'recurring', 'approvals', 'fixed_assets', 'liability_tracking',
  'journal_entries', 'payroll',
  'advanced_reporting',
  'multi_currency',
  'advanced_permissions', 'project_profit', 'api_webhooks',
  'cashflow_forecast', 'priority_support', 'custom_reports',
  'multi_entity'
);

-- Partner: practice console features
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, NULL
FROM pricing_plans p, features f
WHERE p.slug = 'partner' AND f.slug IN (
  'bank_feeds', 'bank_reconciliation', 'gst_bas',
  'contacts', 'financial_reports', 'advanced_reporting',
  'import_export', 'email_support'
);
