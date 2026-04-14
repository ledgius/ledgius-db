-- Seed pricing plans, features, and plan-feature mappings.
-- Idempotent: uses ON CONFLICT DO UPDATE to refresh data.

-- =============================================================================
-- Plans
-- =============================================================================

INSERT INTO pricing_plans (slug, name, description, price_monthly, price_annually, sort_order, is_popular, max_users, max_employees, status) VALUES
  ('starter',       'Starter',       'For sole traders and micro-businesses getting started.',                   0,      0, 1, false, 1,    NULL, 'active'),
  ('essential',     'Essential',     'For small businesses that need invoicing, expenses, and GST.',            29,    290, 2, false, 3,       5, 'active'),
  ('professional',  'Professional',  'For growing businesses with payroll and advanced compliance.',            59,    590, 3, true,  10,     20, 'active'),
  ('business',      'Business',      'For established businesses needing full accounting and unlimited users.', 99,    990, 4, false, NULL,   NULL, 'active')
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
  updated_at = now();

-- =============================================================================
-- Features
-- =============================================================================

INSERT INTO features (slug, name, description, category, sort_order) VALUES
  -- Core
  ('bank_connections',      'Bank Connections',             'Connect bank accounts for automatic transaction imports',   'core',          1),
  ('invoicing',             'Invoicing',                    'Create, send, and track invoices',                          'core',          2),
  ('expense_tracking',      'Expense Tracking',             'Record and categorise business expenses',                   'core',          3),
  ('receipt_capture',       'Receipt Capture',              'Photograph and attach receipts to transactions',            'core',          4),
  ('chart_of_accounts',     'Chart of Accounts',            'Customisable chart of accounts with AU defaults',           'core',          5),
  ('contacts',              'Contact Management',           'Customer and vendor management',                            'core',          6),
  -- Accounting
  ('multi_currency',        'Multi-Currency',               'Transact in multiple currencies with exchange rates',       'accounting',   10),
  ('journal_entries',       'Journal Entries',              'Manual journal entries with approval workflow',              'accounting',   11),
  ('bank_reconciliation',   'Bank Reconciliation',          'Match bank transactions to ledger entries',                  'accounting',   12),
  ('fixed_assets',          'Fixed Assets',                 'Asset register with depreciation schedules',                 'accounting',   13),
  ('recurring_transactions','Recurring Transactions',       'Automate repeating invoices, bills, and journals',           'accounting',   14),
  ('budgeting',             'Budgeting',                    'Set and track budgets by account or department',             'accounting',   15),
  -- Payroll
  ('payroll',               'Payroll',                      'Process pay runs with PAYG, super, and leave',              'payroll',      20),
  ('stp_reporting',         'STP Reporting',                'Single Touch Payroll reporting to ATO',                      'payroll',      21),
  ('leave_management',      'Leave Management',             'Track and accrue employee leave balances',                   'payroll',      22),
  ('super_guarantee',       'Super Guarantee',              'Calculate and track superannuation contributions',           'payroll',      23),
  ('employee_portal',       'Employee Self-Service',        'Employees view payslips and submit leave requests',          'payroll',      24),
  -- Compliance
  ('gst_tracking',          'GST Tracking',                 'Automatic GST calculation on transactions',                  'compliance',   30),
  ('bas_reporting',         'BAS Reporting',                'Generate and lodge Business Activity Statements',            'compliance',   31),
  ('payg_withholding',      'PAYG Withholding',             'Calculate PAYG tax withholding per ATO coefficients',        'compliance',   32),
  ('fbt_reporting',         'FBT Reporting',                'Fringe Benefits Tax tracking and return preparation',        'compliance',   33),
  ('audit_trail',           'Audit Trail',                  'Immutable record of all changes with who, when, why',        'compliance',   34),
  -- Reporting
  ('financial_reports',     'Financial Reports',            'Profit & Loss, Balance Sheet, Trial Balance',                'reporting',    40),
  ('cash_flow',             'Cash Flow Reports',            'Cash flow statement and forecasting',                        'reporting',    41),
  ('aged_receivables',      'Aged Receivables',             'Track outstanding customer invoices by age',                 'reporting',    42),
  ('aged_payables',         'Aged Payables',                'Track outstanding supplier bills by age',                    'reporting',    43),
  ('custom_reports',        'Custom Reports',               'Build custom reports with flexible filters',                 'reporting',    44),
  ('books_health',          'Books Health Dashboard',       'At-a-glance health check across all accounting dimensions',  'reporting',    45),
  -- Integrations
  ('api_access',            'API Access',                   'REST API for custom integrations',                           'integrations', 50),
  ('data_import',           'Data Import',                  'Import from MYOB, Xero, and CSV formats',                   'integrations', 51),
  ('data_export',           'Data Export',                  'Export data in CSV, PDF, and accounting formats',            'integrations', 52),
  -- Support
  ('email_support',         'Email Support',                'Email support during business hours',                        'support',      60),
  ('priority_support',      'Priority Support',             'Priority response with dedicated account manager',           'support',      61),
  ('onboarding',            'Guided Onboarding',            'Personalised setup and data migration assistance',           'support',      62),
  ('accountant_access',     'Accountant Access',            'Invite your accountant with dedicated role and permissions',  'support',      63)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  sort_order = EXCLUDED.sort_order;

-- =============================================================================
-- Plan-Feature Mappings
-- =============================================================================

-- Clear and re-insert (idempotent)
DELETE FROM plan_features;

-- Starter (free): basic invoicing and expenses
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, CASE
    WHEN f.slug = 'bank_connections' THEN '1'
    ELSE NULL
  END
FROM pricing_plans p, features f
WHERE p.slug = 'starter' AND f.slug IN (
  'invoicing', 'expense_tracking', 'contacts', 'chart_of_accounts',
  'bank_connections', 'gst_tracking', 'financial_reports', 'audit_trail',
  'data_import', 'email_support'
);

-- Essential: core accounting + GST/BAS
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, CASE
    WHEN f.slug = 'bank_connections' THEN '3'
    ELSE NULL
  END
FROM pricing_plans p, features f
WHERE p.slug = 'essential' AND f.slug IN (
  'invoicing', 'expense_tracking', 'receipt_capture', 'contacts', 'chart_of_accounts',
  'bank_connections', 'bank_reconciliation', 'recurring_transactions',
  'gst_tracking', 'bas_reporting', 'audit_trail',
  'financial_reports', 'aged_receivables', 'aged_payables', 'books_health',
  'data_import', 'data_export', 'email_support', 'accountant_access'
);

-- Professional: + payroll + compliance + multi-currency
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, CASE
    WHEN f.slug = 'bank_connections' THEN '10'
    ELSE NULL
  END
FROM pricing_plans p, features f
WHERE p.slug = 'professional' AND f.slug IN (
  'invoicing', 'expense_tracking', 'receipt_capture', 'contacts', 'chart_of_accounts',
  'bank_connections', 'bank_reconciliation', 'multi_currency', 'journal_entries',
  'recurring_transactions', 'fixed_assets',
  'payroll', 'stp_reporting', 'leave_management', 'super_guarantee',
  'gst_tracking', 'bas_reporting', 'payg_withholding', 'audit_trail',
  'financial_reports', 'cash_flow', 'aged_receivables', 'aged_payables', 'books_health',
  'data_import', 'data_export', 'email_support', 'accountant_access'
);

-- Business: everything
INSERT INTO plan_features (plan_id, feature_id, enabled, limit_value)
SELECT p.id, f.id, true, CASE
    WHEN f.slug = 'bank_connections' THEN 'unlimited'
    ELSE NULL
  END
FROM pricing_plans p, features f
WHERE p.slug = 'business' AND f.slug IN (
  'invoicing', 'expense_tracking', 'receipt_capture', 'contacts', 'chart_of_accounts',
  'bank_connections', 'bank_reconciliation', 'multi_currency', 'journal_entries',
  'recurring_transactions', 'fixed_assets', 'budgeting',
  'payroll', 'stp_reporting', 'leave_management', 'super_guarantee', 'employee_portal',
  'gst_tracking', 'bas_reporting', 'payg_withholding', 'fbt_reporting', 'audit_trail',
  'financial_reports', 'cash_flow', 'aged_receivables', 'aged_payables', 'custom_reports', 'books_health',
  'api_access', 'data_import', 'data_export',
  'email_support', 'priority_support', 'onboarding', 'accountant_access'
);
