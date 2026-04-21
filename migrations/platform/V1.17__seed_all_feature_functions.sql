-- Spec references: R-0068 (PA-031, PA-034).
--
-- V1.17 — Comprehensive feature function registry.
-- Every API endpoint mapped to its feature + function for role-based gating.
-- Each function has a unique slug: feature:function (e.g. payroll:create_employee).

-- Helper: insert function if feature exists, skip if not.
-- Uses ON CONFLICT to be idempotent.

-- =============================================================================
-- Chart of Accounts (feature: chart_of_accounts — ungated, all plans)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_accounts',    'View Accounts',     'View chart of accounts',              'GET',    '/api/v1/accounts',    1),
  ('create_account',   'Create Account',    'Add new account or heading',          'POST',   '/api/v1/accounts',    2),
  ('edit_account',     'Edit Account',      'Update account details',              'PUT',    '/api/v1/accounts',    3),
  ('delete_account',   'Delete Account',    'Remove an account',                   'DELETE', '/api/v1/accounts',    4)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'chart_of_accounts'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, http_method = EXCLUDED.http_method, path_pattern = EXCLUDED.path_pattern;

-- =============================================================================
-- Contacts (feature: contacts — ungated, all plans)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_contacts',    'View Contacts',     'View customers and vendors',          'GET',    '/api/v1/contacts',    1),
  ('create_contact',   'Create Contact',    'Add new customer or vendor',          'POST',   '/api/v1/contacts',    2),
  ('edit_contact',     'Edit Contact',      'Update contact status and details',   'PATCH',  '/api/v1/contacts',    3)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'contacts'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Invoicing (feature: invoicing)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_invoices',    'View Invoices',     'View invoice list and details',       'GET',    '/api/v1/invoices',    1),
  ('create_invoice',   'Create Invoice',    'Create new invoices',                 'POST',   '/api/v1/invoices',    2),
  ('edit_invoice',     'Edit Invoice',      'Modify draft invoices',               'PUT',    '/api/v1/invoices',    3),
  ('post_invoice',     'Post Invoice',      'Post invoice to the ledger',          'POST',   '/api/v1/invoices',    4),
  ('void_invoice',     'Void Invoice',      'Void a posted invoice',               'POST',   '/api/v1/invoices',    5),
  ('view_pdf',         'View Invoice PDF',  'Generate and view invoice PDF',       'GET',    '/api/v1/invoices',    6),
  ('create_credit_note','Create Credit Note','Issue a credit note',                'POST',   '/api/v1/credit-notes',7),
  ('view_quotes',      'View Quotes',       'View quotes list',                    'GET',    '/api/v1/quotes',      8),
  ('create_quote',     'Create Quote',      'Create a new quote',                  'POST',   '/api/v1/quotes',      9),
  ('send_quote',       'Send Quote',        'Email a quote to customer',           'POST',   '/api/v1/quotes',     10),
  ('convert_quote',    'Convert Quote',     'Convert quote to invoice',            'POST',   '/api/v1/quotes',     11)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'invoicing'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Bills & Expenses (feature: bills)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_bills',       'View Bills',        'View bills and expenses',             'GET',    '/api/v1/bills',       1),
  ('create_bill',      'Create Bill',       'Enter a new bill',                    'POST',   '/api/v1/bills',       2),
  ('edit_bill',        'Edit Bill',         'Update bill vendor and details',      'PATCH',  '/api/v1/bills',       3),
  ('create_debit_note','Create Debit Note', 'Issue a debit note',                  'POST',   '/api/v1/debit-notes', 4),
  ('upload_receipt',   'Upload Receipt',    'Capture receipt image (OCR)',          'POST',   '/api/v1/capture',     5),
  ('view_receipts',    'View Receipts',     'View captured receipts',              'GET',    '/api/v1/capture',     6)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'bills'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Payments (feature: payment_links — part of invoicing/core)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_payments',    'View Payments',     'View payment history',                'GET',    '/api/v1/payments',    1),
  ('create_payment',   'Create Payment',    'Record a payment made',               'POST',   '/api/v1/payments',    2),
  ('receive_payment',  'Receive Payment',   'Record a payment received',           'POST',   '/api/v1/receipts',    3)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'payment_links'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Bank Reconciliation (feature: bank_reconciliation)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_transactions','View Transactions',  'View bank transactions',             'GET',    '/api/v1/banking',     1),
  ('reconcile',        'Reconcile',          'Match and reconcile transactions',    'POST',   '/api/v1/banking',     2),
  ('propose_allocation','Propose Allocation','Propose allocation for review',      'POST',   '/api/v1/banking',     3),
  ('approve_recon',    'Approve Reconciliation','Approve proposed allocations',     'POST',   '/api/v1/banking',     4),
  ('manage_rules',     'Manage Rules',       'Create and edit reconciliation rules','*',      '/api/v1/banking/rules',5),
  ('import_statement', 'Import Statement',   'Upload bank statement file',          'POST',   '/api/v1/banking/import',6),
  ('create_transfer',  'Create Transfer',    'Record inter-account transfer',       'POST',   '/api/v1/transfers',   7),
  ('run_pipeline',     'Run Pipeline',       'Run auto-reconciliation pipeline',    'POST',   '/api/v1/banking',     8)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'bank_reconciliation'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Bank Feeds (feature: bank_feeds)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_connections', 'View Connections',   'View bank feed connections',          'GET',    '/api/v1/bank-feeds',  1),
  ('connect_bank',     'Connect Bank',       'Connect a new bank account',          'POST',   '/api/v1/bank-feeds',  2),
  ('map_account',      'Map Account',        'Map bank feed to ledger account',     'POST',   '/api/v1/bank-feeds',  3),
  ('sync_feed',        'Sync Feed',          'Trigger manual sync',                 'POST',   '/api/v1/bank-feeds',  4),
  ('reauthorise',      'Reauthorise',        'Reauthorise expired connection',      'POST',   '/api/v1/bank-feeds',  5)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'bank_feeds'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Payroll (feature: payroll)
-- =============================================================================
-- Already seeded in V1.16. Add any missing ones.
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_payg_config', 'View PAYG Config',  'View PAYG withholding brackets',      'GET',    '/api/v1/payg-config', 7),
  ('view_super_rates', 'View Super Rates',  'View super guarantee rates',          'GET',    '/api/v1/super-rates', 8)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'payroll'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- GST/BAS Reporting (feature: gst_bas)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('generate_bas',     'Generate BAS',      'Generate Business Activity Statement', 'GET',    '/api/v1/tax/bas',     1),
  ('view_gst_detail',  'View GST Detail',   'View GST transaction detail report',   'GET',    '/api/v1/tax/gst',     2)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'gst_bas'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Financial Reports (feature: financial_reports)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_trial_balance','View Trial Balance','Generate trial balance report',       'GET',    '/api/v1/reports',     1),
  ('view_profit_loss', 'View Profit & Loss','Generate P&L report',                 'GET',    '/api/v1/reports',     2),
  ('view_balance_sheet','View Balance Sheet','Generate balance sheet report',       'GET',    '/api/v1/reports',     3),
  ('view_cash_flow',   'View Cash Flow',    'Generate cash flow statement',         'GET',    '/api/v1/reports',     4),
  ('view_gl_detail',   'View GL Detail',    'General ledger detail report',         'GET',    '/api/v1/reports',     5),
  ('view_performance', 'View Performance',  'Business performance dashboard',       'GET',    '/api/v1/reports',     6)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'financial_reports'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Advanced Reporting (feature: advanced_reporting)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_ar_ageing',   'View AR Ageing',    'Aged receivables report',             'GET',    '/api/v1/reports',     1),
  ('view_ap_ageing',   'View AP Ageing',    'Aged payables report',                'GET',    '/api/v1/reports',     2),
  ('view_customer_stmt','View Customer Statement','Customer account statement',    'GET',    '/api/v1/reports',     3),
  ('view_vendor_stmt', 'View Vendor Statement','Vendor account statement',         'GET',    '/api/v1/reports',     4)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'advanced_reporting'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Journal Entries (feature: journal_entries)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_journals',    'View Journals',     'View journal entries',                'GET',    '/api/v1/gl',          1),
  ('post_journal',     'Post Journal',      'Create and post journal entries',     'POST',   '/api/v1/gl',          2),
  ('close_year',       'Close Year',        'Perform year-end close',              'POST',   '/api/v1/gl',          3),
  ('approve_journal',  'Approve Journal',   'Approve pending journal entries',     'POST',   '/api/v1/gl',          4),
  ('reject_journal',   'Reject Journal',    'Reject pending journal entries',      'POST',   '/api/v1/gl',          5)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'journal_entries'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Recurring Transactions (feature: recurring)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_schedules',   'View Schedules',    'View recurring schedules',            'GET',    '/api/v1/recurring',   1),
  ('create_schedule',  'Create Schedule',   'Set up a recurring schedule',         'POST',   '/api/v1/recurring',   2),
  ('view_due',         'View Due',          'See transactions due for processing', 'GET',    '/api/v1/recurring',   3)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'recurring'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Multi-Currency (feature: multi_currency)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_currencies',  'View Currencies',   'View available currencies',           'GET',    '/api/v1/currencies',  1),
  ('view_rates',       'View Exchange Rates','View exchange rate history',          'GET',    '/api/v1/currencies',  2),
  ('create_rate',      'Create Rate',       'Add a manual exchange rate',          'POST',   '/api/v1/currencies',  3)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'multi_currency'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Fixed Assets (feature: fixed_assets)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_assets',      'View Assets',       'View asset register',                 'GET',    '/api/v1/assets',      1),
  ('buy_asset',        'Buy Asset',         'Record asset purchase',               'POST',   '/api/v1/assets',      2),
  ('sell_asset',       'Sell/Dispose Asset','Record asset sale or disposal',        'POST',   '/api/v1/assets',      3),
  ('run_depreciation', 'Run Depreciation',  'Calculate and post depreciation',     'POST',   '/api/v1/assets',      4)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'fixed_assets'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Mileage (feature: mileage)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_trips',       'View Trips',        'View mileage trip log',               'GET',    '/api/v1/mileage',     1),
  ('log_trip',         'Log Trip',          'Record a business trip',              'POST',   '/api/v1/mileage',     2),
  ('manage_vehicles',  'Manage Vehicles',   'Add and edit vehicles',               '*',      '/api/v1/mileage',     3),
  ('manage_logbook',   'Manage Logbook',    'Start and complete logbook periods',   '*',      '/api/v1/mileage',     4),
  ('view_summary',     'View Summary',      'View mileage summary and claims',     'GET',    '/api/v1/mileage',     5)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'mileage'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Import & Export (feature: import_export)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('create_import',    'Create Import',     'Start a new data import batch',       'POST',   '/api/v1/import',      1),
  ('upload_file',      'Upload File',       'Upload import file',                  'POST',   '/api/v1/import',      2),
  ('analyse_import',   'Analyse Import',    'Analyse and map imported data',       'POST',   '/api/v1/import',      3),
  ('commit_import',    'Commit Import',     'Commit import to the ledger',         'POST',   '/api/v1/import',      4),
  ('reverse_import',   'Reverse Import',    'Reverse a committed import',          'POST',   '/api/v1/import',      5),
  ('view_imports',     'View Imports',      'View import batches and history',     'GET',    '/api/v1/import',      6),
  ('run_export',       'Run Export',        'Export data to Xero/MYOB/QBO',        'POST',   '/api/v1/export',      7)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'import_export'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Audit Trail (feature: audit_trail)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_audit_log',   'View Audit Log',    'View system-wide audit log',          'GET',    '/api/v1/audit-log',   1),
  ('view_entity_activity','View Activity',  'View activity for a specific entity', 'GET',    '/api/v1/',            2)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'audit_trail'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Products (feature: invoicing — products are part of invoicing)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_products',    'View Products',     'View product catalogue',              'GET',    '/api/v1/products',   12),
  ('create_product',   'Create Product',    'Add new product or service',          'POST',   '/api/v1/products',   13),
  ('edit_product',     'Edit Product',      'Update product details',              'PUT',    '/api/v1/products',   14),
  ('delete_product',   'Delete Product',    'Remove a product',                    'DELETE', '/api/v1/products',   15)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'invoicing'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Tax Codes (feature: gst_bas — tax codes are part of GST/BAS)
-- =============================================================================
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view_tax_codes',   'View Tax Codes',    'View tax code list',                  'GET',    '/api/v1/tax-codes',   3),
  ('create_tax_code',  'Create Tax Code',   'Add custom tax code',                 'POST',   '/api/v1/tax-codes',   4),
  ('edit_tax_code',    'Edit Tax Code',     'Update tax code',                     'PUT',    '/api/v1/tax-codes',   5)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'gst_bas'
ON CONFLICT (feature_id, slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- =============================================================================
-- Refresh default role permissions for all new functions
-- =============================================================================

-- Owner: everything
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'owner', ff.id, true FROM feature_functions ff
ON CONFLICT (role, function_id) DO NOTHING;

-- Master Accountant: everything
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'master_accountant', ff.id, true FROM feature_functions ff
ON CONFLICT (role, function_id) DO NOTHING;

-- Accountant: most things except manage_rules, close_year, reverse_import
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'accountant', ff.id, true FROM feature_functions ff
WHERE ff.slug NOT IN ('manage_rules', 'close_year', 'reverse_import')
ON CONFLICT (role, function_id) DO NOTHING;

-- Bookkeeper: view + create + edit, no post/void/lodge/approve/close/reverse
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'bookkeeper', ff.id, true FROM feature_functions ff
WHERE ff.slug LIKE 'view_%'
   OR ff.slug LIKE 'create_%'
   OR ff.slug LIKE 'edit_%'
   OR ff.slug IN ('log_trip', 'upload_receipt', 'reconcile', 'propose_allocation',
                   'import_statement', 'upload_file', 'analyse_import',
                   'run_payroll', 'map_account', 'sync_feed')
ON CONFLICT (role, function_id) DO NOTHING;

-- Viewer: view/read only
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'viewer', ff.id, true FROM feature_functions ff
WHERE ff.http_method = 'GET' OR ff.slug LIKE 'view_%'
ON CONFLICT (role, function_id) DO NOTHING;
