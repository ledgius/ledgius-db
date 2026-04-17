-- Spec references: R-0017 (IMP-PIP-028), A-0017.
--
-- V1.36 — Staging account completeness columns
--
-- The real MYOB AO export and COA file carry fields that the original
-- import_staging_account table (V1.12) had no columns for. These
-- fields were silently dropped during import — unacceptable per the
-- "no data compromises" rule.
--
-- New columns:
--   opening_balance — AO export carries this on every account line.
--   is_header       — COA file Header flag (H = heading/group account,
--                     should not be imported as a postable account).
--   parent_code     — COA file parent-child account hierarchy.
--   is_inactive     — COA file Inactive Account flag (Y/N).

ALTER TABLE import_staging_account
    ADD COLUMN IF NOT EXISTS opening_balance NUMERIC;

ALTER TABLE import_staging_account
    ADD COLUMN IF NOT EXISTS is_header BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE import_staging_account
    ADD COLUMN IF NOT EXISTS parent_code TEXT;

ALTER TABLE import_staging_account
    ADD COLUMN IF NOT EXISTS is_inactive BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN import_staging_account.opening_balance IS
    'Opening balance from the source file (MYOB AO export). Decimal value; NULL when the '
    'source does not provide an opening balance (e.g. CeeData format).';

COMMENT ON COLUMN import_staging_account.is_header IS
    'True when the source account is a heading/group account (MYOB COA file Header="H"). '
    'Header accounts should not be imported as postable GL accounts — they define the chart '
    'hierarchy only. Default false for formats that do not distinguish headers.';

COMMENT ON COLUMN import_staging_account.parent_code IS
    'Source-system parent account code (MYOB COA file "Parent Account Number"). Used to '
    'reconstruct the chart hierarchy during import. NULL when the source does not carry '
    'parent information (e.g. AO export, CeeData).';

COMMENT ON COLUMN import_staging_account.is_inactive IS
    'True when the source marks the account as inactive (MYOB COA file Inactive Account="Y"). '
    'Inactive accounts set account.obsolete=true on commit. Default false.';
