-- Spec references: A-0021.
--
-- R__seed_currencies.sql — Currency Seed Data (repeatable)
--
-- Seeds common currencies into the LedgerSMB-inherited currency table.
-- The currency table is created in V1.00__core_schema.sql.
--
-- Idempotent: uses ON CONFLICT (curr) DO NOTHING.

INSERT INTO currency (curr, description) VALUES ('AUD', 'Australian Dollar')    ON CONFLICT (curr) DO NOTHING;
INSERT INTO currency (curr, description) VALUES ('USD', 'United States Dollar')  ON CONFLICT (curr) DO NOTHING;
INSERT INTO currency (curr, description) VALUES ('GBP', 'British Pound')         ON CONFLICT (curr) DO NOTHING;
INSERT INTO currency (curr, description) VALUES ('EUR', 'Euro')                  ON CONFLICT (curr) DO NOTHING;
INSERT INTO currency (curr, description) VALUES ('NZD', 'New Zealand Dollar')    ON CONFLICT (curr) DO NOTHING;
