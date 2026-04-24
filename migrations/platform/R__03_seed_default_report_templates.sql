-- Spec references: R-0071 (RT-040 through RT-042), T-0033-14.
--
-- Seed default report templates. System templates (is_default=true,
-- tenant_id=NULL) are read-only — users clone to customise.

INSERT INTO report_templates (id, tenant_id, name, description, data_source, category, is_default, template_json, page_size)
VALUES
  -- P&L
  ('00000000-0000-0000-0001-000000000001', NULL,
   'Profit & Loss', 'Standard income and expense summary for a period',
   'profit_loss', 'financial', true,
   '{"root":{"props":{"title":"Profit & Loss"}},"content":[
     {"type":"TextField","props":{"content":"{{business_name}}","fontSize":16,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"Profit & Loss Statement","fontSize":14,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"For the period {{period_start}} to {{period_end}}","fontSize":10,"fontWeight":"normal","alignment":"left"}},
     {"type":"HorizontalRule","props":{"style":"medium"}},
     {"type":"TextField","props":{"content":"Revenue","fontSize":12,"fontWeight":"bold","alignment":"left"}},
     {"type":"DataTable","props":{"dataField":"revenue_lines","columns":"[{\"header\":\"Account\",\"field\":\"account_name\"},{\"header\":\"Amount\",\"field\":\"amount\",\"format\":\"currency\",\"align\":\"right\"}]"}},
     {"type":"SubtotalRow","props":{"label":"Total Revenue","field":"total_revenue","format":"currency","isTotal":"false"}},
     {"type":"Spacer","props":{"height":8}},
     {"type":"TextField","props":{"content":"Expenses","fontSize":12,"fontWeight":"bold","alignment":"left"}},
     {"type":"DataTable","props":{"dataField":"expense_lines","columns":"[{\"header\":\"Account\",\"field\":\"account_name\"},{\"header\":\"Amount\",\"field\":\"amount\",\"format\":\"currency\",\"align\":\"right\"}]"}},
     {"type":"SubtotalRow","props":{"label":"Total Expenses","field":"total_expenses","format":"currency","isTotal":"false"}},
     {"type":"HorizontalRule","props":{"style":"heavy"}},
     {"type":"SubtotalRow","props":{"label":"Net Profit","field":"net_profit","format":"currency","isTotal":"true"}}
   ],"zones":{}}',
   'A4'),

  -- Balance Sheet
  ('00000000-0000-0000-0001-000000000002', NULL,
   'Balance Sheet', 'Assets, liabilities, and equity at a point in time',
   'balance_sheet', 'financial', true,
   '{"root":{"props":{"title":"Balance Sheet"}},"content":[
     {"type":"TextField","props":{"content":"{{business_name}}","fontSize":16,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"Balance Sheet","fontSize":14,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"As at {{as_at_date}}","fontSize":10,"fontWeight":"normal","alignment":"left"}},
     {"type":"HorizontalRule","props":{"style":"medium"}},
     {"type":"SubtotalRow","props":{"label":"Total Assets","field":"total_assets","format":"currency","isTotal":"false"}},
     {"type":"SubtotalRow","props":{"label":"Total Liabilities","field":"total_liabilities","format":"currency","isTotal":"false"}},
     {"type":"HorizontalRule","props":{"style":"heavy"}},
     {"type":"SubtotalRow","props":{"label":"Total Equity","field":"total_equity","format":"currency","isTotal":"true"}}
   ],"zones":{}}',
   'A4'),

  -- Invoice
  ('00000000-0000-0000-0001-000000000003', NULL,
   'Invoice', 'Standard tax invoice with line items',
   'invoice', 'customer', true,
   '{"root":{"props":{"title":"Tax Invoice"}},"content":[
     {"type":"Logo","props":{"source":"tenant","customUrl":"","maxHeight":48}},
     {"type":"TextField","props":{"content":"{{business_name}}","fontSize":14,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"ABN: {{business_abn}}","fontSize":9,"fontWeight":"normal","alignment":"left"}},
     {"type":"Spacer","props":{"height":16}},
     {"type":"TextField","props":{"content":"TAX INVOICE","fontSize":16,"fontWeight":"bold","alignment":"right"}},
     {"type":"TextField","props":{"content":"Invoice: {{invoice_number}}","fontSize":10,"fontWeight":"normal","alignment":"right"}},
     {"type":"TextField","props":{"content":"Date: {{invoice_date}}","fontSize":10,"fontWeight":"normal","alignment":"right"}},
     {"type":"TextField","props":{"content":"Due: {{due_date}}","fontSize":10,"fontWeight":"normal","alignment":"right"}},
     {"type":"HorizontalRule","props":{"style":"light"}},
     {"type":"TextField","props":{"content":"Bill To:","fontSize":9,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"{{customer_name}}","fontSize":10,"fontWeight":"normal","alignment":"left"}},
     {"type":"TextField","props":{"content":"{{customer_address}}","fontSize":10,"fontWeight":"normal","alignment":"left"}},
     {"type":"Spacer","props":{"height":12}},
     {"type":"DataTable","props":{"dataField":"line_items","columns":"[{\"header\":\"Description\",\"field\":\"description\"},{\"header\":\"Qty\",\"field\":\"quantity\",\"align\":\"right\"},{\"header\":\"Unit Price\",\"field\":\"unit_price\",\"format\":\"currency\",\"align\":\"right\"},{\"header\":\"Amount\",\"field\":\"amount\",\"format\":\"currency\",\"align\":\"right\"}]"}},
     {"type":"SubtotalRow","props":{"label":"Subtotal (ex GST)","field":"subtotal","format":"currency","isTotal":"false"}},
     {"type":"SubtotalRow","props":{"label":"GST","field":"gst_amount","format":"currency","isTotal":"false"}},
     {"type":"SubtotalRow","props":{"label":"Total (inc GST)","field":"total","format":"currency","isTotal":"true"}},
     {"type":"Spacer","props":{"height":16}},
     {"type":"TextField","props":{"content":"{{payment_terms}}","fontSize":9,"fontWeight":"normal","alignment":"left"}},
     {"type":"TextField","props":{"content":"{{notes}}","fontSize":9,"fontWeight":"normal","alignment":"left"}}
   ],"zones":{}}',
   'A4'),

  -- Customer Statement
  ('00000000-0000-0000-0001-000000000004', NULL,
   'Customer Statement', 'Customer transaction history with balances',
   'customer_statement', 'customer', true,
   '{"root":{"props":{"title":"Customer Statement"}},"content":[
     {"type":"TextField","props":{"content":"{{business_name}}","fontSize":16,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"Statement of Account","fontSize":14,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"{{customer_name}}","fontSize":12,"fontWeight":"normal","alignment":"left"}},
     {"type":"TextField","props":{"content":"As at {{statement_date}}","fontSize":10,"fontWeight":"normal","alignment":"left"}},
     {"type":"HorizontalRule","props":{"style":"medium"}},
     {"type":"SubtotalRow","props":{"label":"Opening Balance","field":"opening_balance","format":"currency","isTotal":"false"}},
     {"type":"SubtotalRow","props":{"label":"Closing Balance","field":"closing_balance","format":"currency","isTotal":"true"}}
   ],"zones":{}}',
   'A4'),

  -- BAS Worksheet
  ('00000000-0000-0000-0001-000000000005', NULL,
   'BAS Worksheet', 'Business Activity Statement preparation summary',
   'bas_worksheet', 'compliance', true,
   '{"root":{"props":{"title":"BAS Worksheet"}},"content":[
     {"type":"TextField","props":{"content":"{{business_name}}","fontSize":16,"fontWeight":"bold","alignment":"left"}},
     {"type":"TextField","props":{"content":"ABN: {{abn}}","fontSize":10,"fontWeight":"normal","alignment":"left"}},
     {"type":"TextField","props":{"content":"BAS Worksheet — {{period}}","fontSize":14,"fontWeight":"bold","alignment":"left"}},
     {"type":"HorizontalRule","props":{"style":"medium"}},
     {"type":"SubtotalRow","props":{"label":"G1 Total Sales","field":"g1_total_sales","format":"currency","isTotal":"false"}},
     {"type":"SubtotalRow","props":{"label":"GST Collected","field":"gst_collected","format":"currency","isTotal":"false"}},
     {"type":"SubtotalRow","props":{"label":"GST Paid","field":"gst_paid","format":"currency","isTotal":"false"}},
     {"type":"SubtotalRow","props":{"label":"Net GST Payable","field":"net_gst","format":"currency","isTotal":"true"}},
     {"type":"Spacer","props":{"height":8}},
     {"type":"SubtotalRow","props":{"label":"PAYG Withheld","field":"payg_withheld","format":"currency","isTotal":"false"}},
     {"type":"HorizontalRule","props":{"style":"heavy"}},
     {"type":"SubtotalRow","props":{"label":"Total Amount Payable","field":"total_payable","format":"currency","isTotal":"true"}}
   ],"zones":{}}',
   'A4')

ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  template_json = EXCLUDED.template_json,
  updated_at = now();
