-- Spec references: R-0071 (RT-040, RT-041, RT-042), T-0033-14.
--
-- Seed 5 system default report templates. These are read-only
-- templates users can clone to create their own versions.
-- tenant_id IS NULL = system template, is_default = true.
--
-- Template JSON uses Puck's data structure: { root, content, zones }.
-- Each template provides a sensible starting layout for the data source.

INSERT INTO report_templates (id, tenant_id, name, description, data_source, category, template_json, page_size, page_orientation, is_default, is_active, version, created_at, updated_at)
VALUES
  -- 1. Profit & Loss
  (
    '00000000-0000-0000-0000-000000000001',
    NULL,
    'Profit & Loss Statement',
    'Standard profit and loss report showing revenue and expenses for a period.',
    'profit_loss',
    'financial',
    '{"root":{"props":{}},"content":[{"type":"PageHeader","props":{"id":"ph1"}},{"type":"Logo","props":{"id":"logo1","source":"tenant","customUrl":"","maxHeight":48}},{"type":"TextField","props":{"id":"tf1","content":"Profit & Loss Statement","fontSize":18,"fontWeight":"bold","alignment":"center"}},{"type":"DataField","props":{"id":"df1","fieldSlug":"period_start","label":"Period","format":"date","fontSize":10,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df2","fieldSlug":"period_end","label":"To","format":"date","fontSize":10,"fontWeight":"normal"}},{"type":"HorizontalRule","props":{"id":"hr1","style":"medium"}},{"type":"TextField","props":{"id":"tf2","content":"Revenue","fontSize":14,"fontWeight":"bold","alignment":"left"}},{"type":"DataTable","props":{"id":"dt1","dataField":"revenue_lines","columns":"[{\"header\":\"Account\",\"field\":\"account_name\"},{\"header\":\"Amount\",\"field\":\"amount\",\"format\":\"currency\",\"align\":\"right\"}]"}},{"type":"SubtotalRow","props":{"id":"st1","label":"Total Revenue","field":"total_revenue","format":"currency","isTotal":"true"}},{"type":"Spacer","props":{"id":"sp1","height":16}},{"type":"TextField","props":{"id":"tf3","content":"Expenses","fontSize":14,"fontWeight":"bold","alignment":"left"}},{"type":"DataTable","props":{"id":"dt2","dataField":"expense_lines","columns":"[{\"header\":\"Account\",\"field\":\"account_name\"},{\"header\":\"Amount\",\"field\":\"amount\",\"format\":\"currency\",\"align\":\"right\"}]"}},{"type":"SubtotalRow","props":{"id":"st2","label":"Total Expenses","field":"total_expenses","format":"currency","isTotal":"true"}},{"type":"HorizontalRule","props":{"id":"hr2","style":"heavy"}},{"type":"SubtotalRow","props":{"id":"st3","label":"Net Profit / (Loss)","field":"net_profit","format":"currency","isTotal":"true"}},{"type":"PageFooter","props":{"id":"pf1","showPageNumbers":"true"}}],"zones":{}}'::jsonb,
    'A4', 'portrait', TRUE, TRUE, 1, NOW(), NOW()
  ),

  -- 2. Balance Sheet
  (
    '00000000-0000-0000-0000-000000000002',
    NULL,
    'Balance Sheet',
    'Statement of financial position showing assets, liabilities, and equity.',
    'balance_sheet',
    'financial',
    '{"root":{"props":{}},"content":[{"type":"PageHeader","props":{"id":"ph1"}},{"type":"Logo","props":{"id":"logo1","source":"tenant","customUrl":"","maxHeight":48}},{"type":"TextField","props":{"id":"tf1","content":"Balance Sheet","fontSize":18,"fontWeight":"bold","alignment":"center"}},{"type":"DataField","props":{"id":"df1","fieldSlug":"as_at_date","label":"As at","format":"date","fontSize":10,"fontWeight":"normal"}},{"type":"HorizontalRule","props":{"id":"hr1","style":"medium"}},{"type":"TextField","props":{"id":"tf2","content":"Assets","fontSize":14,"fontWeight":"bold","alignment":"left"}},{"type":"DataTable","props":{"id":"dt1","dataField":"asset_lines","columns":"[{\"header\":\"Account\",\"field\":\"account_name\"},{\"header\":\"Balance\",\"field\":\"balance\",\"format\":\"currency\",\"align\":\"right\"}]"}},{"type":"SubtotalRow","props":{"id":"st1","label":"Total Assets","field":"total_assets","format":"currency","isTotal":"true"}},{"type":"Spacer","props":{"id":"sp1","height":16}},{"type":"TextField","props":{"id":"tf3","content":"Liabilities","fontSize":14,"fontWeight":"bold","alignment":"left"}},{"type":"DataTable","props":{"id":"dt2","dataField":"liability_lines","columns":"[{\"header\":\"Account\",\"field\":\"account_name\"},{\"header\":\"Balance\",\"field\":\"balance\",\"format\":\"currency\",\"align\":\"right\"}]"}},{"type":"SubtotalRow","props":{"id":"st2","label":"Total Liabilities","field":"total_liabilities","format":"currency","isTotal":"true"}},{"type":"Spacer","props":{"id":"sp2","height":16}},{"type":"TextField","props":{"id":"tf4","content":"Equity","fontSize":14,"fontWeight":"bold","alignment":"left"}},{"type":"DataTable","props":{"id":"dt3","dataField":"equity_lines","columns":"[{\"header\":\"Account\",\"field\":\"account_name\"},{\"header\":\"Balance\",\"field\":\"balance\",\"format\":\"currency\",\"align\":\"right\"}]"}},{"type":"SubtotalRow","props":{"id":"st3","label":"Total Equity","field":"total_equity","format":"currency","isTotal":"true"}},{"type":"PageFooter","props":{"id":"pf1","showPageNumbers":"true"}}],"zones":{}}'::jsonb,
    'A4', 'portrait', TRUE, TRUE, 1, NOW(), NOW()
  ),

  -- 3. Invoice
  (
    '00000000-0000-0000-0000-000000000003',
    NULL,
    'Tax Invoice',
    'Standard Australian tax invoice layout with GST breakdown.',
    'invoice',
    'document',
    '{"root":{"props":{}},"content":[{"type":"Logo","props":{"id":"logo1","source":"tenant","customUrl":"","maxHeight":48}},{"type":"TextField","props":{"id":"tf1","content":"TAX INVOICE","fontSize":20,"fontWeight":"bold","alignment":"right"}},{"type":"HorizontalRule","props":{"id":"hr1","style":"medium"}},{"type":"DataField","props":{"id":"df1","fieldSlug":"business_name","label":"From","format":"text","fontSize":10,"fontWeight":"bold"}},{"type":"DataField","props":{"id":"df2","fieldSlug":"business_abn","label":"ABN","format":"text","fontSize":9,"fontWeight":"normal"}},{"type":"Spacer","props":{"id":"sp1","height":12}},{"type":"DataField","props":{"id":"df3","fieldSlug":"customer_name","label":"Bill To","format":"text","fontSize":10,"fontWeight":"bold"}},{"type":"Spacer","props":{"id":"sp2","height":12}},{"type":"DataField","props":{"id":"df4","fieldSlug":"invoice_number","label":"Invoice #","format":"text","fontSize":10,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df5","fieldSlug":"invoice_date","label":"Date","format":"date","fontSize":10,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df6","fieldSlug":"due_date","label":"Due","format":"date","fontSize":10,"fontWeight":"normal"}},{"type":"HorizontalRule","props":{"id":"hr2","style":"light"}},{"type":"DataTable","props":{"id":"dt1","dataField":"line_items","columns":"[{\"header\":\"Description\",\"field\":\"description\"},{\"header\":\"Qty\",\"field\":\"quantity\",\"align\":\"right\"},{\"header\":\"Unit Price\",\"field\":\"unit_price\",\"format\":\"currency\",\"align\":\"right\"},{\"header\":\"GST\",\"field\":\"tax_amount\",\"format\":\"currency\",\"align\":\"right\"},{\"header\":\"Amount\",\"field\":\"amount\",\"format\":\"currency\",\"align\":\"right\"}]"}},{"type":"SubtotalRow","props":{"id":"st1","label":"Subtotal (ex GST)","field":"subtotal","format":"currency","isTotal":"false"}},{"type":"SubtotalRow","props":{"id":"st2","label":"GST","field":"total_tax","format":"currency","isTotal":"false"}},{"type":"SubtotalRow","props":{"id":"st3","label":"Total (inc GST)","field":"total","format":"currency","isTotal":"true"}},{"type":"PageFooter","props":{"id":"pf1","showPageNumbers":"false"}}],"zones":{}}'::jsonb,
    'A4', 'portrait', TRUE, TRUE, 1, NOW(), NOW()
  ),

  -- 4. Customer Statement
  (
    '00000000-0000-0000-0000-000000000004',
    NULL,
    'Customer Statement',
    'Transaction statement for a customer showing outstanding balance.',
    'customer_statement',
    'document',
    '{"root":{"props":{}},"content":[{"type":"Logo","props":{"id":"logo1","source":"tenant","customUrl":"","maxHeight":48}},{"type":"TextField","props":{"id":"tf1","content":"STATEMENT","fontSize":18,"fontWeight":"bold","alignment":"right"}},{"type":"HorizontalRule","props":{"id":"hr1","style":"medium"}},{"type":"DataField","props":{"id":"df1","fieldSlug":"business_name","label":"From","format":"text","fontSize":10,"fontWeight":"bold"}},{"type":"DataField","props":{"id":"df2","fieldSlug":"customer_name","label":"To","format":"text","fontSize":10,"fontWeight":"bold"}},{"type":"Spacer","props":{"id":"sp1","height":8}},{"type":"DateField","props":{"id":"dtf1","source":"now","fieldSlug":"","dateFormat":"d-month-yyyy"}},{"type":"HorizontalRule","props":{"id":"hr2","style":"light"}},{"type":"DataTable","props":{"id":"dt1","dataField":"transaction_lines","columns":"[{\"header\":\"Date\",\"field\":\"date\",\"format\":\"date\"},{\"header\":\"Reference\",\"field\":\"reference\"},{\"header\":\"Description\",\"field\":\"description\"},{\"header\":\"Debit\",\"field\":\"debit\",\"format\":\"currency\",\"align\":\"right\"},{\"header\":\"Credit\",\"field\":\"credit\",\"format\":\"currency\",\"align\":\"right\"},{\"header\":\"Balance\",\"field\":\"running_balance\",\"format\":\"currency\",\"align\":\"right\"}]"}},{"type":"SubtotalRow","props":{"id":"st1","label":"Balance Due","field":"balance_due","format":"currency","isTotal":"true"}},{"type":"PageFooter","props":{"id":"pf1","showPageNumbers":"true"}}],"zones":{}}'::jsonb,
    'A4', 'portrait', TRUE, TRUE, 1, NOW(), NOW()
  ),

  -- 5. BAS Worksheet
  (
    '00000000-0000-0000-0000-000000000005',
    NULL,
    'BAS Worksheet',
    'Business Activity Statement preparation worksheet with GST summary.',
    'bas_worksheet',
    'compliance',
    '{"root":{"props":{}},"content":[{"type":"Logo","props":{"id":"logo1","source":"tenant","customUrl":"","maxHeight":48}},{"type":"TextField","props":{"id":"tf1","content":"BAS Worksheet","fontSize":18,"fontWeight":"bold","alignment":"center"}},{"type":"DataField","props":{"id":"df1","fieldSlug":"period_start","label":"Period","format":"date","fontSize":10,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df2","fieldSlug":"period_end","label":"To","format":"date","fontSize":10,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df3","fieldSlug":"business_abn","label":"ABN","format":"text","fontSize":10,"fontWeight":"normal"}},{"type":"HorizontalRule","props":{"id":"hr1","style":"medium"}},{"type":"DataField","props":{"id":"df4","fieldSlug":"g1_total_sales","label":"G1 — Total Sales","format":"currency","fontSize":11,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df5","fieldSlug":"g3_gst_free","label":"G3 — GST-free Sales","format":"currency","fontSize":11,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df6","fieldSlug":"g10_capital","label":"G10 — Capital Acquisitions","format":"currency","fontSize":11,"fontWeight":"normal"}},{"type":"DataField","props":{"id":"df7","fieldSlug":"g11_non_capital","label":"G11 — Non-capital Acquisitions","format":"currency","fontSize":11,"fontWeight":"normal"}},{"type":"HorizontalRule","props":{"id":"hr2","style":"light"}},{"type":"SubtotalRow","props":{"id":"st1","label":"1A — GST on Sales","field":"gst_on_sales","format":"currency","isTotal":"false"}},{"type":"SubtotalRow","props":{"id":"st2","label":"1B — GST on Purchases","field":"gst_on_purchases","format":"currency","isTotal":"false"}},{"type":"SubtotalRow","props":{"id":"st3","label":"Net GST Payable / (Refund)","field":"net_gst","format":"currency","isTotal":"true"}},{"type":"PageFooter","props":{"id":"pf1","showPageNumbers":"false"}}],"zones":{}}'::jsonb,
    'A4', 'portrait', TRUE, TRUE, 1, NOW(), NOW()
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  template_json = EXCLUDED.template_json,
  updated_at = NOW();
