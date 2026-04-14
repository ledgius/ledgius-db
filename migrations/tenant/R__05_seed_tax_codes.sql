-- Spec references: A-0021.
--
-- R__seed_tax_codes.sql — Tax Code Seed Data (repeatable)
--
-- Seeds the Australian tax codes used across the platform.
-- Also links GST codes to GL accounts where they exist.
--
-- Idempotent: uses ON CONFLICT (code) DO NOTHING for inserts.
-- UPDATE statements for GL account links are safe to re-run (conditional on NULL).

-- Australian tax codes
INSERT INTO tax_code (code, name, description, rate, jurisdiction, tax_type, active)
VALUES
    ('GST', 'GST',        'Goods and Services Tax — standard rate 10%',     0.1000, 'AU', 'gst',  true),
    ('FRE', 'GST-Free',   'GST-free supply (Division 38)',                   0.0000, 'AU', 'gst',  true),
    ('INP', 'Input Taxed','Input taxed supply (Division 40) — no GST, no ITC', 0.0000, 'AU', 'gst', true),
    ('EXP', 'Export',     'GST-free export supply',                          0.0000, 'AU', 'gst',  true),
    ('N-T', 'No Tax',     'Not subject to GST (out of scope)',               0.0000, 'AU', 'none', true),
    ('CAP', 'GST on Capital', 'GST on capital acquisitions (BAS G10)',       0.1000, 'AU', 'gst',  true)
ON CONFLICT (code) DO NOTHING;

-- Link GST code to GST Collected account (2200) if it exists.
UPDATE tax_code SET chart_account_id = (
    SELECT id FROM account WHERE accno = '2200' LIMIT 1
) WHERE code = 'GST' AND chart_account_id IS NULL;

-- Link CAP code to GST Paid account (1200) if it exists.
UPDATE tax_code SET chart_account_id = (
    SELECT id FROM account WHERE accno = '1200' LIMIT 1
) WHERE code = 'CAP' AND chart_account_id IS NULL;
