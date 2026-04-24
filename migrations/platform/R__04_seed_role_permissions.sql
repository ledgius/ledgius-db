-- Spec references: R-0068 (PA-034).
--
-- R__04 — Repeatable re-assertion of role → function permissions.
--
-- Why repeatable:
--   * Permission policy is "current state", not history. When it drifts
--     (someone manually revokes a row, a V-script forgets to grant, a
--     middleware adds a new function slug), this script pulls it back.
--   * `owner` and `master_accountant` are defined to hold EVERY function
--     unconditionally — adding a new feature_function row automatically
--     grants them here on the next deploy.
--
-- Every insert uses ON CONFLICT (role, function_id) DO UPDATE SET
-- allowed = true so that re-runs are idempotent AND self-healing
-- (revoked rows get re-granted).
--
-- -----------------------------------------------------------------------------
-- Step 1 — Reconcile the `fixed_assets` function slug vocabulary
-- -----------------------------------------------------------------------------
--
-- pkg/middleware/role_permissions.go (DefaultRoleFunctionMap) references
-- fixed_assets:{view, create, edit} for the /api/v1/assets routes, but
-- V1.17 seeded the feature with slugs view_assets / buy_asset / sell_asset
-- / run_depreciation. That vocabulary mismatch means the guard lookup
-- always misses — every role (including `owner`) gets 403 on the Asset
-- Register page.
--
-- We keep the legacy slugs (harmless, may be referenced by admin UI) and
-- add the generic verbs the middleware actually asks for. When someone
-- eventually reconciles the Go map + DB vocabulary the legacy slugs can
-- be removed in a V-script.

INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.descr, fn.method, fn.path, fn.sort
FROM features f, (VALUES
  ('view',   'View Asset Register', 'View asset register (middleware slug)', 'GET',   '/api/v1/assets', 100),
  ('create', 'Create Asset',        'Create asset (middleware slug)',        'POST',  '/api/v1/assets', 101),
  ('edit',   'Edit Asset',          'Edit asset (middleware slug)',          'PATCH', '/api/v1/assets', 102)
) AS fn(slug, name, descr, method, path, sort)
WHERE f.slug = 'fixed_assets'
ON CONFLICT (feature_id, slug) DO UPDATE SET
    name         = EXCLUDED.name,
    description  = EXCLUDED.description,
    http_method  = EXCLUDED.http_method,
    path_pattern = EXCLUDED.path_pattern;

-- -----------------------------------------------------------------------------
-- Step 2 — Owner: every function, always.
-- -----------------------------------------------------------------------------
--
-- Owner is the tenant's highest role. Self-healing grant — if an owner
-- row was accidentally deleted or a new feature_function was added
-- without a matching grant, this pulls it back.

INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'owner', ff.id, true FROM feature_functions ff
ON CONFLICT (role, function_id) DO UPDATE SET allowed = true;

-- -----------------------------------------------------------------------------
-- Step 3 — Master Accountant: every function, always.
-- -----------------------------------------------------------------------------

INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'master_accountant', ff.id, true FROM feature_functions ff
ON CONFLICT (role, function_id) DO UPDATE SET allowed = true;

-- -----------------------------------------------------------------------------
-- Step 4 — Accountant: everything except high-risk actions.
-- -----------------------------------------------------------------------------
--
-- Excluded: manage_rules (reconciliation auto-match can post journals),
-- close_year (irreversible period close), reverse_import (undoes a
-- committed batch).

INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'accountant', ff.id, true FROM feature_functions ff
 WHERE ff.slug NOT IN ('manage_rules', 'close_year', 'reverse_import')
ON CONFLICT (role, function_id) DO UPDATE SET allowed = true;

-- -----------------------------------------------------------------------------
-- Step 5 — Bookkeeper: day-to-day entry, not approval / posting.
-- -----------------------------------------------------------------------------
--
-- view_/create_/edit_ verbs + a hand-picked set of non-risk actions
-- (reconcile, upload_receipt, etc.). Explicitly no *post*, *void*,
-- *lodge*, *approve*, *close*, *reverse*, or *delete*.

INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'bookkeeper', ff.id, true FROM feature_functions ff
 WHERE ff.slug LIKE 'view_%'
    OR ff.slug LIKE 'create_%'
    OR ff.slug LIKE 'edit_%'
    OR ff.slug IN (
         -- Generic verbs (fixed_assets uses these, not the _asset variants).
         'view', 'create', 'edit',
         -- Mileage / receipts.
         'log_trip', 'upload_receipt',
         -- Reconciliation tasks that don't commit auto-rules.
         'reconcile', 'propose_allocation', 'import_statement',
         -- Import pipeline up to (but not including) commit.
         'upload_file', 'analyse_import',
         -- Payroll + bank-feed routine tasks.
         'run_payroll', 'map_account', 'sync_feed'
       )
ON CONFLICT (role, function_id) DO UPDATE SET allowed = true;

-- -----------------------------------------------------------------------------
-- Step 6 — Viewer: read-only.
-- -----------------------------------------------------------------------------
--
-- Any function bound to an HTTP GET method, or slug starting with view_,
-- plus the new generic `view` slug. Explicitly excludes POST/PUT/PATCH/DELETE
-- even if the slug happens to start with view (defensive).

INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'viewer', ff.id, true FROM feature_functions ff
 WHERE (ff.http_method = 'GET' OR ff.slug LIKE 'view_%' OR ff.slug = 'view')
ON CONFLICT (role, function_id) DO UPDATE SET allowed = true;
