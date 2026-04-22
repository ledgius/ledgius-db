-- Spec references: R-0071 (RT-011 through RT-013), T-0033-01.
--
-- V1.49 — Data source field catalogue for the report template designer.
-- Each data source publishes its available fields so the template editor
-- can populate the field picker.

CREATE TABLE IF NOT EXISTS data_source_fields (
    id              SERIAL PRIMARY KEY,
    data_source     TEXT NOT NULL,
    field_slug      TEXT NOT NULL,
    field_name      TEXT NOT NULL,
    field_type      TEXT NOT NULL DEFAULT 'string'
        CHECK (field_type IN ('string', 'number', 'currency', 'date', 'boolean', 'list')),
    category        TEXT,
    description     TEXT,
    sort_order      INT NOT NULL DEFAULT 0,
    UNIQUE (data_source, field_slug)
);

COMMENT ON TABLE data_source_fields IS
    'Field catalogue for report data sources. The template editor reads this '
    'to populate the field picker when designing report layouts.';

CREATE INDEX IF NOT EXISTS idx_data_source_fields_source
    ON data_source_fields(data_source);

-- =============================================================================
-- Seed field catalogues for built-in data sources
-- =============================================================================

-- Profit & Loss
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('profit_loss', 'business_name',       'Business Name',        'string',   'business',  1),
  ('profit_loss', 'abn',                 'ABN',                  'string',   'business',  2),
  ('profit_loss', 'period_start',        'Period Start',         'date',     'period',    3),
  ('profit_loss', 'period_end',          'Period End',           'date',     'period',    4),
  ('profit_loss', 'total_revenue',       'Total Revenue',        'currency', 'revenue',   10),
  ('profit_loss', 'total_expenses',      'Total Expenses',       'currency', 'expenses',  20),
  ('profit_loss', 'net_profit',          'Net Profit',           'currency', 'summary',   30),
  ('profit_loss', 'gross_margin_pct',    'Gross Margin %',       'number',   'summary',   31),
  ('profit_loss', 'revenue_lines',       'Revenue Line Items',   'list',     'revenue',   11),
  ('profit_loss', 'expense_lines',       'Expense Line Items',   'list',     'expenses',  21),
  ('profit_loss', 'report_date',         'Report Date',          'date',     'period',    5)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name, field_type = EXCLUDED.field_type;

-- Balance Sheet
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('balance_sheet', 'business_name',     'Business Name',        'string',   'business',  1),
  ('balance_sheet', 'as_at_date',        'As At Date',           'date',     'period',    2),
  ('balance_sheet', 'total_assets',      'Total Assets',         'currency', 'assets',    10),
  ('balance_sheet', 'total_liabilities', 'Total Liabilities',    'currency', 'liabilities', 20),
  ('balance_sheet', 'total_equity',      'Total Equity',         'currency', 'equity',    30),
  ('balance_sheet', 'asset_lines',       'Asset Line Items',     'list',     'assets',    11),
  ('balance_sheet', 'liability_lines',   'Liability Line Items', 'list',     'liabilities', 21),
  ('balance_sheet', 'equity_lines',      'Equity Line Items',    'list',     'equity',    31)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name;

-- Trial Balance
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('trial_balance', 'business_name',     'Business Name',        'string',   'business',  1),
  ('trial_balance', 'as_at_date',        'As At Date',           'date',     'period',    2),
  ('trial_balance', 'total_debits',      'Total Debits',         'currency', 'summary',   10),
  ('trial_balance', 'total_credits',     'Total Credits',        'currency', 'summary',   11),
  ('trial_balance', 'account_lines',     'Account Lines',        'list',     'accounts',  20)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name;

-- Invoice
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('invoice', 'business_name',          'Business Name',        'string',   'business',  1),
  ('invoice', 'business_abn',           'Business ABN',         'string',   'business',  2),
  ('invoice', 'business_address',       'Business Address',     'string',   'business',  3),
  ('invoice', 'business_phone',         'Business Phone',       'string',   'business',  4),
  ('invoice', 'business_email',         'Business Email',       'string',   'business',  5),
  ('invoice', 'business_logo',          'Business Logo',        'string',   'business',  6),
  ('invoice', 'invoice_number',         'Invoice Number',       'string',   'invoice',   10),
  ('invoice', 'invoice_date',           'Invoice Date',         'date',     'invoice',   11),
  ('invoice', 'due_date',               'Due Date',             'date',     'invoice',   12),
  ('invoice', 'reference',              'Reference',            'string',   'invoice',   13),
  ('invoice', 'customer_name',          'Customer Name',        'string',   'customer',  20),
  ('invoice', 'customer_address',       'Customer Address',     'string',   'customer',  21),
  ('invoice', 'customer_email',         'Customer Email',       'string',   'customer',  22),
  ('invoice', 'line_items',             'Invoice Lines',        'list',     'lines',     30),
  ('invoice', 'subtotal',               'Subtotal (ex GST)',    'currency', 'totals',    40),
  ('invoice', 'gst_amount',             'GST Amount',           'currency', 'totals',    41),
  ('invoice', 'total',                  'Total (inc GST)',      'currency', 'totals',    42),
  ('invoice', 'amount_paid',            'Amount Paid',          'currency', 'totals',    43),
  ('invoice', 'amount_due',             'Amount Due',           'currency', 'totals',    44),
  ('invoice', 'payment_terms',          'Payment Terms',        'string',   'payment',   50),
  ('invoice', 'bank_details',           'Bank Details',         'string',   'payment',   51),
  ('invoice', 'notes',                  'Notes',                'string',   'notes',     60)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name;

-- Customer Statement
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('customer_statement', 'business_name',    'Business Name',     'string',   'business',  1),
  ('customer_statement', 'customer_name',    'Customer Name',     'string',   'customer',  10),
  ('customer_statement', 'customer_address', 'Customer Address',  'string',   'customer',  11),
  ('customer_statement', 'statement_date',   'Statement Date',    'date',     'period',    20),
  ('customer_statement', 'opening_balance',  'Opening Balance',   'currency', 'balances',  30),
  ('customer_statement', 'closing_balance',  'Closing Balance',   'currency', 'balances',  31),
  ('customer_statement', 'transaction_lines','Transaction Lines', 'list',     'transactions', 40),
  ('customer_statement', 'ageing_current',   'Current',           'currency', 'ageing',    50),
  ('customer_statement', 'ageing_30',        '30 Days',           'currency', 'ageing',    51),
  ('customer_statement', 'ageing_60',        '60 Days',           'currency', 'ageing',    52),
  ('customer_statement', 'ageing_90',        '90+ Days',          'currency', 'ageing',    53)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name;

-- Vendor Statement
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('vendor_statement', 'business_name',      'Business Name',     'string',   'business',  1),
  ('vendor_statement', 'vendor_name',        'Vendor Name',       'string',   'vendor',    10),
  ('vendor_statement', 'statement_date',     'Statement Date',    'date',     'period',    20),
  ('vendor_statement', 'opening_balance',    'Opening Balance',   'currency', 'balances',  30),
  ('vendor_statement', 'closing_balance',    'Closing Balance',   'currency', 'balances',  31),
  ('vendor_statement', 'transaction_lines',  'Transaction Lines', 'list',     'transactions', 40)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name;

-- Cash Flow
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('cash_flow', 'business_name',             'Business Name',           'string',   'business',    1),
  ('cash_flow', 'period_start',              'Period Start',            'date',     'period',      2),
  ('cash_flow', 'period_end',                'Period End',              'date',     'period',      3),
  ('cash_flow', 'operating_activities',      'Operating Activities',    'currency', 'operating',   10),
  ('cash_flow', 'investing_activities',      'Investing Activities',    'currency', 'investing',   20),
  ('cash_flow', 'financing_activities',      'Financing Activities',    'currency', 'financing',   30),
  ('cash_flow', 'net_change',                'Net Change in Cash',      'currency', 'summary',     40),
  ('cash_flow', 'opening_cash',              'Opening Cash Balance',    'currency', 'summary',     41),
  ('cash_flow', 'closing_cash',              'Closing Cash Balance',    'currency', 'summary',     42)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name;

-- BAS Worksheet
INSERT INTO data_source_fields (data_source, field_slug, field_name, field_type, category, sort_order) VALUES
  ('bas_worksheet', 'business_name',         'Business Name',           'string',   'business',    1),
  ('bas_worksheet', 'abn',                   'ABN',                     'string',   'business',    2),
  ('bas_worksheet', 'period',                'BAS Period',              'string',   'period',      3),
  ('bas_worksheet', 'g1_total_sales',        'G1 Total Sales',          'currency', 'gst',         10),
  ('bas_worksheet', 'g2_export_sales',       'G2 Export Sales',         'currency', 'gst',         11),
  ('bas_worksheet', 'g3_gst_free',           'G3 GST-Free Sales',       'currency', 'gst',         12),
  ('bas_worksheet', 'g10_capital_purchases', 'G10 Capital Purchases',   'currency', 'gst',         13),
  ('bas_worksheet', 'g11_non_capital',       'G11 Non-Capital Purchases','currency','gst',         14),
  ('bas_worksheet', 'gst_collected',         'GST Collected',           'currency', 'summary',     20),
  ('bas_worksheet', 'gst_paid',              'GST Paid',                'currency', 'summary',     21),
  ('bas_worksheet', 'net_gst',               'Net GST Payable',         'currency', 'summary',     22),
  ('bas_worksheet', 'payg_withheld',         'PAYG Withheld',           'currency', 'payg',        30),
  ('bas_worksheet', 'payg_instalment',       'PAYG Instalment',         'currency', 'payg',        31),
  ('bas_worksheet', 'total_payable',         'Total Amount Payable',    'currency', 'summary',     40)
ON CONFLICT (data_source, field_slug) DO UPDATE SET field_name = EXCLUDED.field_name;
