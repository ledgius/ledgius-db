-- Spec references: R-0041.
--
-- Pricing plans, features, and tenant subscription management.
-- Plans are configurable with per-feature enable/disable.
-- Tenants are linked to a plan with active date ranges.

-- =============================================================================
-- 1. Pricing Plans
-- =============================================================================

CREATE TABLE IF NOT EXISTS pricing_plans (
    id              SERIAL PRIMARY KEY,
    slug            TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    description     TEXT,
    price_monthly   NUMERIC(10,2) NOT NULL DEFAULT 0,
    price_annually  NUMERIC(10,2) NOT NULL DEFAULT 0,
    billing_cycle   TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'annually')),
    currency        TEXT NOT NULL DEFAULT 'AUD',
    sort_order      INT NOT NULL DEFAULT 0,
    is_popular      BOOLEAN NOT NULL DEFAULT false,
    max_users       INT,
    max_employees   INT,
    active_from     DATE NOT NULL DEFAULT CURRENT_DATE,
    active_until    DATE,
    status          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'draft', 'archived')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE pricing_plans IS 'Configurable pricing tiers. Each plan defines price, limits, and which features are enabled.';
COMMENT ON COLUMN pricing_plans.slug IS 'URL-safe identifier, e.g. starter, professional, business';
COMMENT ON COLUMN pricing_plans.is_popular IS 'Highlighted as "Most Popular" on the pricing page';
COMMENT ON COLUMN pricing_plans.max_users IS 'User seat limit. NULL = unlimited.';
COMMENT ON COLUMN pricing_plans.max_employees IS 'Payroll employee limit. NULL = unlimited.';
COMMENT ON COLUMN pricing_plans.active_from IS 'Plan available for new signups from this date';
COMMENT ON COLUMN pricing_plans.active_until IS 'Plan no longer available after this date. NULL = no expiry.';

-- =============================================================================
-- 2. Features
-- =============================================================================

CREATE TABLE IF NOT EXISTS features (
    id              SERIAL PRIMARY KEY,
    slug            TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    description     TEXT,
    category        TEXT NOT NULL DEFAULT 'core',
    sort_order      INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE features IS 'Product features that can be enabled/disabled per pricing plan.';
COMMENT ON COLUMN features.category IS 'Feature grouping: core, accounting, payroll, compliance, reporting, integrations, support';

-- =============================================================================
-- 3. Plan Features (which features are enabled per plan)
-- =============================================================================

CREATE TABLE IF NOT EXISTS plan_features (
    plan_id     INT NOT NULL REFERENCES pricing_plans(id) ON DELETE CASCADE,
    feature_id  INT NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    enabled     BOOLEAN NOT NULL DEFAULT true,
    limit_value TEXT,
    PRIMARY KEY (plan_id, feature_id)
);

COMMENT ON TABLE plan_features IS 'Maps features to plans. enabled=true means the feature is included in that plan.';
COMMENT ON COLUMN plan_features.limit_value IS 'Optional limit for the feature in this plan, e.g. "5" for 5 bank accounts, "unlimited"';

-- =============================================================================
-- 4. Tenant Subscriptions
-- =============================================================================

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS plan_id INT REFERENCES pricing_plans(id);
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_start DATE;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_end DATE;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS trial_ends_at DATE;

COMMENT ON COLUMN tenants.plan_id IS 'Current pricing plan. NULL = free/trial.';
COMMENT ON COLUMN tenants.trial_ends_at IS 'Trial expiry date. NULL = not on trial.';

CREATE INDEX IF NOT EXISTS idx_pricing_plans_status ON pricing_plans(status);
CREATE INDEX IF NOT EXISTS idx_features_category ON features(category);
