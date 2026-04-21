-- Spec references: R-0068 (PA-031, PA-034).
--
-- V1.16 — Feature functions and role-based permissions.
-- Features define what a tenant's plan includes (plan-level gate).
-- Functions define what a user role can do within a feature (role-level gate).
--
-- Security model: plan_features (tenant can access feature) +
-- role_function_permissions (user role can perform function).
-- Both are inclusion-based (explicit allows).

-- =============================================================================
-- 1. Feature Functions — granular actions within a feature
-- =============================================================================

CREATE TABLE IF NOT EXISTS feature_functions (
    id          SERIAL PRIMARY KEY,
    feature_id  INT NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    slug        TEXT NOT NULL,
    name        TEXT NOT NULL,
    description TEXT,
    http_method TEXT NOT NULL DEFAULT '*'
        CHECK (http_method IN ('*', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE')),
    path_pattern TEXT,
    sort_order  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (feature_id, slug)
);

COMMENT ON TABLE feature_functions IS
    'Granular actions within a feature. Each function maps to one or more '
    'API operations (e.g. "create_pay_run" within the payroll feature). '
    'Role permissions are assigned at the function level.';
COMMENT ON COLUMN feature_functions.slug IS
    'Unique identifier within the feature, e.g. "create_pay_run", "view_payslips".';
COMMENT ON COLUMN feature_functions.http_method IS
    'HTTP method this function maps to. * = all methods. '
    'Used by the route guard to match request method to function.';
COMMENT ON COLUMN feature_functions.path_pattern IS
    'Optional URL path pattern this function applies to, e.g. "/api/v1/employees". '
    'Used by the centralised route guard for automatic matching.';

CREATE INDEX IF NOT EXISTS idx_feature_functions_feature
    ON feature_functions(feature_id);

-- =============================================================================
-- 2. Role Function Permissions — what each role can do
-- =============================================================================

CREATE TABLE IF NOT EXISTS role_function_permissions (
    id              SERIAL PRIMARY KEY,
    role            TEXT NOT NULL
        CHECK (role IN ('owner', 'master_accountant', 'accountant', 'bookkeeper', 'viewer')),
    function_id     INT NOT NULL REFERENCES feature_functions(id) ON DELETE CASCADE,
    allowed         BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (role, function_id)
);

COMMENT ON TABLE role_function_permissions IS
    'Maps user roles to feature functions. Inclusion-based: if a row exists '
    'with allowed=true, the role can perform that function. No row = denied. '
    'Platform owners configure this via the admin console.';

CREATE INDEX IF NOT EXISTS idx_role_function_perms_role
    ON role_function_permissions(role);
CREATE INDEX IF NOT EXISTS idx_role_function_perms_function
    ON role_function_permissions(function_id);

-- =============================================================================
-- 3. Seed default functions for existing features
-- =============================================================================

-- Payroll functions
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.description, fn.method, fn.path, fn.sort
FROM features f,
(VALUES
    ('view_employees',   'View Employees',    'View employee list and details',       'GET',    '/api/v1/employees', 1),
    ('create_employee',  'Create Employee',   'Add a new employee',                   'POST',   '/api/v1/employees', 2),
    ('edit_employee',    'Edit Employee',     'Update employee details',              'PUT',    '/api/v1/employees', 3),
    ('run_payroll',      'Run Payroll',       'Create and process pay runs',          'POST',   '/api/v1/pay-runs',  4),
    ('view_payslips',    'View Payslips',     'View payslip history',                 'GET',    '/api/v1/pay-runs',  5),
    ('lodge_stp',        'Lodge STP',         'Submit STP reports to the ATO',        'POST',   '/api/v1/stp',       6)
) AS fn(slug, name, description, method, path, sort)
WHERE f.slug = 'payroll'
ON CONFLICT (feature_id, slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    http_method = EXCLUDED.http_method,
    path_pattern = EXCLUDED.path_pattern;

-- Invoicing functions
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.description, fn.method, fn.path, fn.sort
FROM features f,
(VALUES
    ('view_invoices',    'View Invoices',     'View invoice list and details',        'GET',    '/api/v1/invoices',  1),
    ('create_invoice',   'Create Invoice',    'Create new invoices and quotes',       'POST',   '/api/v1/invoices',  2),
    ('edit_invoice',     'Edit Invoice',      'Modify draft invoices',                'PUT',    '/api/v1/invoices',  3),
    ('post_invoice',     'Post Invoice',      'Post invoice to the ledger',           'POST',   '/api/v1/invoices',  4),
    ('void_invoice',     'Void Invoice',      'Void a posted invoice',                'POST',   '/api/v1/invoices',  5)
) AS fn(slug, name, description, method, path, sort)
WHERE f.slug = 'invoicing'
ON CONFLICT (feature_id, slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

-- Bank reconciliation functions
INSERT INTO feature_functions (feature_id, slug, name, description, http_method, path_pattern, sort_order)
SELECT f.id, fn.slug, fn.name, fn.description, fn.method, fn.path, fn.sort
FROM features f,
(VALUES
    ('view_transactions', 'View Transactions',  'View bank transactions',               'GET',    '/api/v1/banking',   1),
    ('reconcile',         'Reconcile',          'Match and reconcile transactions',      'POST',   '/api/v1/banking',   2),
    ('approve_recon',     'Approve Reconciliation', 'Approve proposed allocations',      'POST',   '/api/v1/banking',   3),
    ('manage_rules',      'Manage Rules',       'Create and edit reconciliation rules',  '*',      '/api/v1/banking',   4)
) AS fn(slug, name, description, method, path, sort)
WHERE f.slug = 'bank_reconciliation'
ON CONFLICT (feature_id, slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

-- =============================================================================
-- 4. Seed default role permissions
-- =============================================================================

-- Owner: everything
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'owner', ff.id, true
FROM feature_functions ff
ON CONFLICT (role, function_id) DO NOTHING;

-- Master Accountant: everything
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'master_accountant', ff.id, true
FROM feature_functions ff
ON CONFLICT (role, function_id) DO NOTHING;

-- Accountant: most things except manage_rules
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'accountant', ff.id, true
FROM feature_functions ff
WHERE ff.slug NOT IN ('manage_rules')
ON CONFLICT (role, function_id) DO NOTHING;

-- Bookkeeper: view + create + edit, no post/void/lodge/approve
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'bookkeeper', ff.id, true
FROM feature_functions ff
WHERE ff.slug IN (
    'view_employees', 'create_employee', 'edit_employee',
    'view_invoices', 'create_invoice', 'edit_invoice',
    'view_transactions', 'reconcile',
    'view_payslips', 'run_payroll'
)
ON CONFLICT (role, function_id) DO NOTHING;

-- Viewer: view only
INSERT INTO role_function_permissions (role, function_id, allowed)
SELECT 'viewer', ff.id, true
FROM feature_functions ff
WHERE ff.http_method = 'GET' OR ff.slug LIKE 'view_%'
ON CONFLICT (role, function_id) DO NOTHING;
