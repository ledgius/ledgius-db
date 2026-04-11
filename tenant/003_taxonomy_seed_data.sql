-- Seed data: Australian tax taxonomy tree.
-- Reference: docs/architecture/knowledge_ingestion_pipeline_v3.md section 7.

-- =============================================================================
-- Level 0: Root domains
-- =============================================================================

INSERT INTO taxonomy_node (canonical_key, name, description, level, node_type, status)
VALUES
    ('tax', 'Taxation', 'Australian taxation domain', 0, 'domain', 'active'),
    ('reporting', 'Reporting', 'Statutory and business reporting', 0, 'domain', 'active'),
    ('accounting', 'Accounting', 'Australian accounting standards and principles', 0, 'domain', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Level 1: Tax categories
-- =============================================================================

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax'),
     'tax.gst', 'Goods and Services Tax', 'GST — A New Tax System (Goods and Services Tax) Act 1999', 1, 'category', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax'),
     'tax.payg', 'PAYG', 'Pay As You Go withholding and instalments', 1, 'category', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax'),
     'tax.fbt', 'Fringe Benefits Tax', 'Fringe Benefits Tax Assessment Act 1986', 1, 'category', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax'),
     'tax.income', 'Income Tax', 'Income Tax Assessment Act 1936/1997', 1, 'category', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Level 2: GST subcategories
-- =============================================================================

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'),
     'tax.gst.classification', 'GST Classification', 'Supply classification rules (taxable, GST-free, input taxed)', 2, 'subcategory', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'),
     'tax.gst.registration', 'GST Registration', 'Registration thresholds and requirements', 2, 'subcategory', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'),
     'tax.gst.reporting', 'GST Reporting', 'BAS reporting labels and lodgement rules', 2, 'subcategory', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'),
     'tax.gst.input_tax_credits', 'Input Tax Credits', 'Entitlement to and claiming of input tax credits', 2, 'subcategory', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'),
     'tax.gst.adjustments', 'GST Adjustments', 'Division 19 and 21 adjustments', 2, 'subcategory', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'),
     'tax.gst.tax_invoices', 'Tax Invoices', 'Tax invoice requirements under Division 29', 2, 'subcategory', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Level 3: GST Classification leaves
-- =============================================================================

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.classification'),
     'tax.gst.classification.taxable_supply', 'Taxable Supply', 'Division 9 — taxable supply definition and conditions', 3, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.classification'),
     'tax.gst.classification.gst_free', 'GST-Free Supply', 'Division 38 — GST-free supplies', 3, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.classification'),
     'tax.gst.classification.input_taxed', 'Input Taxed Supply', 'Division 40 — input taxed supplies', 3, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.classification'),
     'tax.gst.classification.out_of_scope', 'Out of Scope', 'Transactions not subject to GST', 3, 'leaf', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Level 3: GST Reporting — BAS labels
-- =============================================================================

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting'),
     'tax.gst.reporting.bas', 'BAS GST Section', 'Business Activity Statement GST reporting section', 3, 'subcategory', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g1', 'G1 — Total Sales', 'Total sales and income (including any GST)', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g2', 'G2 — Export Sales', 'Export sales', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g3', 'G3 — Other GST-Free Sales', 'Other GST-free sales', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g4', 'G4 — Input Taxed Sales', 'Input taxed sales', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g5', 'G5 — G2+G3+G4', 'Total non-taxable sales (sum of G2, G3, G4)', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g6', 'G6 — Total Taxable Sales', 'Total taxable sales (G1 minus G5)', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g7', 'G7 — Adjustments', 'Adjustments for the period', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g8', 'G8 — Total GST on Sales', 'Total GST on sales', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g9', 'G9 — Total GST on Sales after Adjustments', 'G8 plus G7', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g10', 'G10 — Capital Purchases', 'Capital purchases', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g11', 'G11 — Non-Capital Purchases', 'Non-capital purchases', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g13', 'G13 — Purchases without GST in Price', 'Purchases that do not include GST', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g14', 'G14 — Purchases with Input Tax Credits', 'Purchases with input tax credit entitlement', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g15', 'G15 — Estimated Purchases without Credits', 'Estimated purchases for private or exempt use', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g18', 'G18 — Adjustments on Purchases', 'Adjustments for the period (purchases)', 4, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.reporting.bas'),
     'tax.gst.reporting.bas.g20', 'G20 — Total GST on Purchases', 'Total GST on purchases after adjustments', 4, 'leaf', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Level 2: PAYG subcategories
-- =============================================================================

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.payg'),
     'tax.payg.withholding', 'PAYG Withholding', 'PAYG withholding obligations and rates', 2, 'subcategory', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.payg'),
     'tax.payg.instalments', 'PAYG Instalments', 'PAYG instalment obligations', 2, 'subcategory', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Level 1: Reporting categories
-- =============================================================================

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting'),
     'reporting.bas', 'Business Activity Statement', 'BAS lodgement and reporting requirements', 1, 'category', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting'),
     'reporting.ias', 'Instalment Activity Statement', 'IAS lodgement and reporting', 1, 'category', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting'),
     'reporting.tpar', 'Taxable Payments Annual Report', 'TPAR reporting obligations', 1, 'category', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting'),
     'reporting.stp', 'Single Touch Payroll', 'STP reporting for payroll', 1, 'category', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Level 2: Reporting BAS labels (cross-ref to tax.gst.reporting.bas)
-- =============================================================================

INSERT INTO taxonomy_node (parent_id, canonical_key, name, description, level, node_type, status)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting.bas'),
     'reporting.bas.label.1A', 'Label 1A — GST on Sales', 'GST collected on sales (maps from G9)', 2, 'leaf', 'active'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting.bas'),
     'reporting.bas.label.1B', 'Label 1B — GST on Purchases', 'GST paid on purchases (maps from G20)', 2, 'leaf', 'active')
ON CONFLICT (canonical_key) DO NOTHING;

-- =============================================================================
-- Taxonomy aliases
-- =============================================================================

INSERT INTO taxonomy_alias (taxonomy_node_id, alias, alias_type)
VALUES
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'), 'GST', 'abbreviation'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst'), 'Goods and Services Tax', 'synonym'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.payg'), 'PAYG', 'abbreviation'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.payg'), 'Pay As You Go', 'synonym'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.fbt'), 'FBT', 'abbreviation'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting.bas'), 'BAS', 'abbreviation'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'reporting.stp'), 'STP', 'abbreviation'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.classification.taxable_supply'), 'Division 9', 'external_ref'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.classification.gst_free'), 'Division 38', 'external_ref'),
    ((SELECT id FROM taxonomy_node WHERE canonical_key = 'tax.gst.classification.input_taxed'), 'Division 40', 'external_ref')
ON CONFLICT (taxonomy_node_id, alias) DO NOTHING;
