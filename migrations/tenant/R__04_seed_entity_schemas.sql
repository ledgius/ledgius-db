-- Spec references: A-0021.
--
-- R__seed_entity_schemas.sql — Entity Schema Seed Data (repeatable)
--
-- Seeds initial enumerations and entity schemas used for artifact binding
-- in the knowledge pipeline. Each schema represents a core domain entity
-- that knowledge artifacts must bind to.
--
-- Idempotent: uses ON CONFLICT DO NOTHING throughout.
--
-- Reference: docs/architecture/knowledge_ingestion_pipeline_v3.md section 8.

-- =============================================================================
-- Enumerations
-- =============================================================================

INSERT INTO enumeration (name, values_json, status)
VALUES
    ('supply_type',      '["taxable", "gst_free", "input_taxed", "out_of_scope"]', 'active'),
    ('gst_rate',         '["standard_10", "zero", "not_applicable"]', 'active'),
    ('bas_label',        '["G1","G2","G3","G4","G5","G6","G7","G8","G9","G10","G11","G13","G14","G15","G18","G20","1A","1B"]', 'active'),
    ('journal_type',     '["general", "sales", "purchase", "cash_receipt", "cash_payment", "adjustment"]', 'active'),
    ('entity_type',      '["individual", "company", "trust", "partnership", "sole_trader", "government", "nfp"]', 'active'),
    ('payg_category',    '["employee", "contractor", "voluntary", "no_tfn", "foreign_resident"]', 'active'),
    ('tax_period_type',  '["monthly", "quarterly", "annual"]', 'active')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- Entity Schema: Transaction (v1)
-- =============================================================================

INSERT INTO entity_schema (name, version, schema_kind, schema_json, status, effective_from)
VALUES ('Transaction', 1, 'entity', '{"description": "Core transaction entity for GST and accounting"}', 'active', '2025-01-01T00:00:00Z')
ON CONFLICT (name, version) DO NOTHING;

INSERT INTO schema_field (entity_schema_id, field_path, field_name, field_type, nullable, enum_id, description)
SELECT es.id, f.field_path, f.field_name, f.field_type, f.nullable, e.id, f.description
FROM (VALUES
    ('txn.id',              'id',              'int',     false, NULL, 'Transaction primary key'),
    ('txn.trans_date',      'trans_date',      'date',    false, NULL, 'Transaction date'),
    ('txn.post_date',       'post_date',       'date',    true,  NULL, 'Posting date'),
    ('txn.description',     'description',     'string',  true,  NULL, 'Transaction description'),
    ('txn.net_amount',      'net_amount',      'decimal', false, NULL, 'Net amount excluding GST'),
    ('txn.gst_amount',      'gst_amount',      'decimal', false, NULL, 'GST amount'),
    ('txn.gross_amount',    'gross_amount',    'decimal', false, NULL, 'Gross amount including GST'),
    ('txn.supply_type',     'supply_type',     'enum',    false, 'supply_type', 'GST supply classification'),
    ('txn.gst_rate',        'gst_rate',        'enum',    false, 'gst_rate', 'Applied GST rate'),
    ('txn.jurisdiction',    'jurisdiction',    'string',  false, NULL, 'Tax jurisdiction code, e.g. AU'),
    ('txn.counterparty_id', 'counterparty_id', 'int',     true,  NULL, 'Reference to counterparty entity'),
    ('txn.account_id',      'account_id',      'int',     false, NULL, 'Chart of accounts reference'),
    ('txn.report_labels',   'report_labels',   'array',   true,  NULL, 'BAS report labels this txn maps to, e.g. ["G1","G6"]'),
    ('txn.is_capital',      'is_capital',      'bool',    false, NULL, 'Whether this is a capital acquisition')
) AS f(field_path, field_name, field_type, nullable, enum_name, description)
CROSS JOIN entity_schema es
LEFT JOIN enumeration e ON e.name = f.enum_name
WHERE es.name = 'Transaction' AND es.version = 1
ON CONFLICT (entity_schema_id, field_path) DO NOTHING;

-- =============================================================================
-- Entity Schema: Invoice (v1)
-- =============================================================================

INSERT INTO entity_schema (name, version, schema_kind, schema_json, status, effective_from)
VALUES ('Invoice', 1, 'entity', '{"description": "Tax invoice entity per Division 29"}', 'active', '2025-01-01T00:00:00Z')
ON CONFLICT (name, version) DO NOTHING;

INSERT INTO schema_field (entity_schema_id, field_path, field_name, field_type, nullable, description)
SELECT es.id, f.field_path, f.field_name, f.field_type, f.nullable, f.description
FROM (VALUES
    ('invoice.id',             'id',             'int',     false, 'Invoice primary key'),
    ('invoice.invoice_number', 'invoice_number', 'string',  false, 'Invoice number'),
    ('invoice.issue_date',     'issue_date',     'date',    false, 'Date of issue'),
    ('invoice.due_date',       'due_date',       'date',    true,  'Payment due date'),
    ('invoice.supplier_abn',   'supplier_abn',   'string',  false, 'Supplier ABN'),
    ('invoice.supplier_name',  'supplier_name',  'string',  false, 'Supplier name'),
    ('invoice.recipient_abn',  'recipient_abn',  'string',  true,  'Recipient ABN'),
    ('invoice.net_amount',     'net_amount',     'decimal', false, 'Total net amount'),
    ('invoice.gst_amount',     'gst_amount',     'decimal', false, 'Total GST amount'),
    ('invoice.gross_amount',   'gross_amount',   'decimal', false, 'Total gross amount'),
    ('invoice.is_tax_invoice', 'is_tax_invoice', 'bool',    false, 'Whether this meets tax invoice requirements'),
    ('invoice.currency',       'currency',       'string',  false, 'Currency code, e.g. AUD')
) AS f(field_path, field_name, field_type, nullable, description)
CROSS JOIN entity_schema es
WHERE es.name = 'Invoice' AND es.version = 1
ON CONFLICT (entity_schema_id, field_path) DO NOTHING;

-- =============================================================================
-- Entity Schema: LedgerPosting (v1)
-- =============================================================================

INSERT INTO entity_schema (name, version, schema_kind, schema_json, status, effective_from)
VALUES ('LedgerPosting', 1, 'entity', '{"description": "Double-entry ledger posting"}', 'active', '2025-01-01T00:00:00Z')
ON CONFLICT (name, version) DO NOTHING;

INSERT INTO schema_field (entity_schema_id, field_path, field_name, field_type, nullable, description)
SELECT es.id, f.field_path, f.field_name, f.field_type, f.nullable, f.description
FROM (VALUES
    ('posting.id',            'id',            'int',     false, 'Posting primary key'),
    ('posting.journal_id',    'journal_id',    'int',     false, 'Parent journal reference'),
    ('posting.account_id',    'account_id',    'int',     false, 'Chart of accounts reference'),
    ('posting.debit_amount',  'debit_amount',  'decimal', false, 'Debit amount'),
    ('posting.credit_amount', 'credit_amount', 'decimal', false, 'Credit amount'),
    ('posting.post_date',     'post_date',     'date',    false, 'Posting date'),
    ('posting.memo',          'memo',          'string',  true,  'Line memo')
) AS f(field_path, field_name, field_type, nullable, description)
CROSS JOIN entity_schema es
WHERE es.name = 'LedgerPosting' AND es.version = 1
ON CONFLICT (entity_schema_id, field_path) DO NOTHING;

-- =============================================================================
-- Entity Schema: BASReport (v1)
-- =============================================================================

INSERT INTO entity_schema (name, version, schema_kind, schema_json, status, effective_from)
VALUES ('BASReport', 1, 'report', '{"description": "Business Activity Statement report entity"}', 'active', '2025-01-01T00:00:00Z')
ON CONFLICT (name, version) DO NOTHING;

INSERT INTO schema_field (entity_schema_id, field_path, field_name, field_type, nullable, enum_id, description)
SELECT es.id, f.field_path, f.field_name, f.field_type, f.nullable, e.id, f.description
FROM (VALUES
    ('bas.id',                'id',                'int',     false, NULL, 'Report primary key'),
    ('bas.period_start',      'period_start',      'date',    false, NULL, 'Reporting period start'),
    ('bas.period_end',        'period_end',        'date',    false, NULL, 'Reporting period end'),
    ('bas.period_type',       'period_type',       'enum',    false, 'tax_period_type', 'Monthly, quarterly, or annual'),
    ('bas.g1_total_sales',    'g1_total_sales',    'decimal', false, NULL, 'G1 — Total sales including GST'),
    ('bas.g2_export_sales',   'g2_export_sales',   'decimal', false, NULL, 'G2 — Export sales'),
    ('bas.g3_gst_free',       'g3_gst_free',       'decimal', false, NULL, 'G3 — Other GST-free sales'),
    ('bas.g4_input_taxed',    'g4_input_taxed',    'decimal', false, NULL, 'G4 — Input taxed sales'),
    ('bas.g5_non_taxable',    'g5_non_taxable',    'decimal', false, NULL, 'G5 — Total non-taxable (G2+G3+G4)'),
    ('bas.g6_taxable_sales',  'g6_taxable_sales',  'decimal', false, NULL, 'G6 — Total taxable sales (G1-G5)'),
    ('bas.g7_adjustments',    'g7_adjustments',    'decimal', false, NULL, 'G7 — Adjustments'),
    ('bas.g8_gst_on_sales',   'g8_gst_on_sales',   'decimal', false, NULL, 'G8 — Total GST on sales'),
    ('bas.g9_gst_after_adj',  'g9_gst_after_adj',  'decimal', false, NULL, 'G9 — GST on sales after adjustments'),
    ('bas.g10_capital',       'g10_capital',        'decimal', false, NULL, 'G10 — Capital purchases'),
    ('bas.g11_non_capital',   'g11_non_capital',    'decimal', false, NULL, 'G11 — Non-capital purchases'),
    ('bas.g20_gst_purchases', 'g20_gst_purchases',  'decimal', false, NULL, 'G20 — Total GST on purchases'),
    ('bas.label_1a',          'label_1a',           'decimal', false, NULL, '1A — GST on sales (from G9)'),
    ('bas.label_1b',          'label_1b',           'decimal', false, NULL, '1B — GST on purchases (from G20)')
) AS f(field_path, field_name, field_type, nullable, enum_name, description)
CROSS JOIN entity_schema es
LEFT JOIN enumeration e ON e.name = f.enum_name
WHERE es.name = 'BASReport' AND es.version = 1
ON CONFLICT (entity_schema_id, field_path) DO NOTHING;

-- =============================================================================
-- Entity Schema: TaxTreatment (v1)
-- =============================================================================

INSERT INTO entity_schema (name, version, schema_kind, schema_json, status, effective_from)
VALUES ('TaxTreatment', 1, 'tax_treatment', '{"description": "Tax treatment determination for a transaction"}', 'active', '2025-01-01T00:00:00Z')
ON CONFLICT (name, version) DO NOTHING;

INSERT INTO schema_field (entity_schema_id, field_path, field_name, field_type, nullable, enum_id, description)
SELECT es.id, f.field_path, f.field_name, f.field_type, f.nullable, e.id, f.description
FROM (VALUES
    ('treatment.supply_type',    'supply_type',    'enum',   false, 'supply_type', 'Determined supply classification'),
    ('treatment.gst_rate',       'gst_rate',       'enum',   false, 'gst_rate', 'Applicable GST rate'),
    ('treatment.bas_labels',     'bas_labels',     'array',  false, NULL, 'BAS labels this treatment maps to'),
    ('treatment.itc_eligible',   'itc_eligible',   'bool',   false, NULL, 'Whether input tax credits can be claimed'),
    ('treatment.authority_ref',  'authority_ref',  'string', true,  NULL, 'Legislative reference for this treatment'),
    ('treatment.effective_from', 'effective_from', 'date',   false, NULL, 'Treatment effective from date'),
    ('treatment.effective_to',   'effective_to',   'date',   true,  NULL, 'Treatment effective to date (null = current)')
) AS f(field_path, field_name, field_type, nullable, enum_name, description)
CROSS JOIN entity_schema es
LEFT JOIN enumeration e ON e.name = f.enum_name
WHERE es.name = 'TaxTreatment' AND es.version = 1
ON CONFLICT (entity_schema_id, field_path) DO NOTHING;

-- =============================================================================
-- Entity Schema: Counterparty (v1)
-- =============================================================================

INSERT INTO entity_schema (name, version, schema_kind, schema_json, status, effective_from)
VALUES ('Counterparty', 1, 'entity', '{"description": "Trading partner / counterparty entity"}', 'active', '2025-01-01T00:00:00Z')
ON CONFLICT (name, version) DO NOTHING;

INSERT INTO schema_field (entity_schema_id, field_path, field_name, field_type, nullable, enum_id, description)
SELECT es.id, f.field_path, f.field_name, f.field_type, f.nullable, e.id, f.description
FROM (VALUES
    ('counterparty.id',             'id',             'int',    false, NULL, 'Counterparty primary key'),
    ('counterparty.name',           'name',           'string', false, NULL, 'Legal or trading name'),
    ('counterparty.abn',            'abn',            'string', true,  NULL, 'Australian Business Number'),
    ('counterparty.entity_type',    'entity_type',    'enum',   true,  'entity_type', 'Entity type classification'),
    ('counterparty.gst_registered', 'gst_registered', 'bool',   false, NULL, 'Whether registered for GST'),
    ('counterparty.country',        'country',        'string', false, NULL, 'Country code, e.g. AU')
) AS f(field_path, field_name, field_type, nullable, enum_name, description)
CROSS JOIN entity_schema es
LEFT JOIN enumeration e ON e.name = f.enum_name
WHERE es.name = 'Counterparty' AND es.version = 1
ON CONFLICT (entity_schema_id, field_path) DO NOTHING;

-- =============================================================================
-- Entity Schema: TaxPeriod (v1)
-- =============================================================================

INSERT INTO entity_schema (name, version, schema_kind, schema_json, status, effective_from)
VALUES ('TaxPeriod', 1, 'entity', '{"description": "Tax reporting period"}', 'active', '2025-01-01T00:00:00Z')
ON CONFLICT (name, version) DO NOTHING;

INSERT INTO schema_field (entity_schema_id, field_path, field_name, field_type, nullable, enum_id, description)
SELECT es.id, f.field_path, f.field_name, f.field_type, f.nullable, e.id, f.description
FROM (VALUES
    ('period.id',            'id',            'int',    false, NULL, 'Period primary key'),
    ('period.period_type',   'period_type',   'enum',   false, 'tax_period_type', 'Monthly, quarterly, or annual'),
    ('period.start_date',    'start_date',    'date',   false, NULL, 'Period start date'),
    ('period.end_date',      'end_date',      'date',   false, NULL, 'Period end date'),
    ('period.due_date',      'due_date',      'date',   false, NULL, 'Lodgement due date'),
    ('period.financial_year','financial_year','string', false, NULL, 'Financial year, e.g. 2025-26')
) AS f(field_path, field_name, field_type, nullable, enum_name, description)
CROSS JOIN entity_schema es
LEFT JOIN enumeration e ON e.name = f.enum_name
WHERE es.name = 'TaxPeriod' AND es.version = 1
ON CONFLICT (entity_schema_id, field_path) DO NOTHING;
