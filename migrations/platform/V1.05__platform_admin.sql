-- Spec references: R-0068, A-0038.
--
-- V1.05 — Platform administration tables
--
-- Extends the platform schema with: sign-up queue, async operations,
-- audit events, support tickets, backup management, tenant extensions,
-- and pricing plan versioning.

-- =============================================================================
-- 1. Tenant extensions
-- =============================================================================

ALTER TABLE tenants
    ADD COLUMN IF NOT EXISTS is_test BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS business_type TEXT,
    ADD COLUMN IF NOT EXISTS trading_name TEXT,
    ADD COLUMN IF NOT EXISTS address_street TEXT,
    ADD COLUMN IF NOT EXISTS address_city TEXT,
    ADD COLUMN IF NOT EXISTS address_state TEXT,
    ADD COLUMN IF NOT EXISTS address_postcode TEXT,
    ADD COLUMN IF NOT EXISTS accountant_user_id UUID,
    ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT,
    ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS deleted_by TEXT,
    ADD COLUMN IF NOT EXISTS deletion_reason TEXT,
    ADD COLUMN IF NOT EXISTS last_backup_at TIMESTAMPTZ;

-- Extend status check to include new states
DO $$
BEGIN
    ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_status_check;
    ALTER TABLE tenants ADD CONSTRAINT tenants_status_check
        CHECK (status IN ('pending', 'provisioning', 'provisioning_failed',
            'active', 'trial', 'suspended', 'restore_in_progress',
            'deletion_pending', 'deleted', 'cancelled'));
END $$;

-- Add role column to users if not exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'business_owner';

COMMENT ON COLUMN tenants.is_test IS 'Test tenants are not billed via Stripe. Used for demos, testing, onboarding prep.';
COMMENT ON COLUMN tenants.business_type IS 'Industry/business type, e.g. Agriculture, Health & Beauty, Services.';
COMMENT ON COLUMN tenants.accountant_user_id IS 'Platform user ID of the assigned accountant.';
COMMENT ON COLUMN users.role IS 'User role: platform_owner, accountant, region_manager, business_owner, bookkeeper, viewer.';

-- =============================================================================
-- 2. Sign-up queue
-- =============================================================================

CREATE TABLE IF NOT EXISTS signup_request (
    id              SERIAL PRIMARY KEY,
    business_name   TEXT NOT NULL,
    contact_name    TEXT NOT NULL,
    email           TEXT NOT NULL,
    phone           TEXT,
    abn             TEXT,
    business_type   TEXT,
    address_state   TEXT,
    address_city    TEXT,
    requested_plan  TEXT,
    referral_source TEXT,
    status          TEXT NOT NULL DEFAULT 'pending_review',
    reviewed_by     TEXT,
    reviewed_at     TIMESTAMPTZ,
    rejection_reason TEXT,
    abn_validation_status     TEXT DEFAULT 'not_checked',
    email_verification_status TEXT DEFAULT 'not_sent',
    risk_score                NUMERIC(5,2),
    review_notes              TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'signup_request' AND constraint_name = 'signup_request_status_check'
    ) THEN
        ALTER TABLE signup_request
            ADD CONSTRAINT signup_request_status_check
            CHECK (status IN ('pending_review', 'accepted', 'rejected',
                'provisioning_started', 'provisioning_failed', 'provisioned'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_signup_status ON signup_request(status);

COMMENT ON TABLE signup_request IS 'Queue of pending business sign-ups awaiting platform owner review.';

-- =============================================================================
-- 3. Pricing plan versioning
-- =============================================================================

CREATE TABLE IF NOT EXISTS pricing_plan_version (
    id              SERIAL PRIMARY KEY,
    plan_id         INT NOT NULL REFERENCES pricing_plans(id),
    version_label   TEXT NOT NULL,
    monthly_price   NUMERIC(10,2) NOT NULL,
    yearly_price    NUMERIC(10,2) NOT NULL,
    monthly_discount_pct  NUMERIC(5,2) DEFAULT 0,
    monthly_discount_from TIMESTAMPTZ,
    monthly_discount_until TIMESTAMPTZ,
    yearly_discount_pct   NUMERIC(5,2) DEFAULT 0,
    yearly_discount_from  TIMESTAMPTZ,
    yearly_discount_until TIMESTAMPTZ,
    trial_days      INT NOT NULL DEFAULT 30,
    effective_from  DATE NOT NULL,
    effective_until DATE,
    capabilities    JSONB NOT NULL DEFAULT '{}',
    entitlements    JSONB NOT NULL DEFAULT '{}',
    is_current      BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_plan_version_current
    ON pricing_plan_version(plan_id) WHERE is_current = true;

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS plan_version_id INT REFERENCES pricing_plan_version(id);

-- Add marketing metadata to pricing_plans
ALTER TABLE pricing_plans
    ADD COLUMN IF NOT EXISTS tagline TEXT,
    ADD COLUMN IF NOT EXISTS feature_bullets JSONB DEFAULT '[]',
    ADD COLUMN IF NOT EXISTS badge_text TEXT,
    ADD COLUMN IF NOT EXISTS cta_text TEXT DEFAULT 'Start Free Trial';

COMMENT ON TABLE pricing_plan_version IS 'Versioned commercial terms for pricing plans. Old subscribers keep their version.';

-- =============================================================================
-- 4. Feature overrides (per-tenant exceptions)
-- =============================================================================

CREATE TABLE IF NOT EXISTS feature_override (
    id              SERIAL PRIMARY KEY,
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    feature         TEXT NOT NULL,
    enabled         BOOLEAN NOT NULL,
    reason          TEXT,
    expires_at      TIMESTAMPTZ,
    created_by      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, feature)
);

COMMENT ON TABLE feature_override IS 'Per-tenant feature gate overrides. Override wins over plan defaults.';

-- =============================================================================
-- 5. Async operations
-- =============================================================================

CREATE TABLE IF NOT EXISTS platform_operation (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_type  TEXT NOT NULL,
    tenant_id       UUID,
    status          TEXT NOT NULL DEFAULT 'pending',
    requested_by    UUID NOT NULL,
    requested_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    input_payload   JSONB NOT NULL DEFAULT '{}',
    output_payload  JSONB,
    error_message   TEXT,
    retry_count     INT NOT NULL DEFAULT 0,
    max_retries     INT NOT NULL DEFAULT 3,
    idempotency_key TEXT UNIQUE,
    parent_id       UUID REFERENCES platform_operation(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'platform_operation' AND constraint_name = 'platform_operation_status_check'
    ) THEN
        ALTER TABLE platform_operation
            ADD CONSTRAINT platform_operation_status_check
            CHECK (status IN ('pending', 'in_progress', 'completed', 'failed', 'cancelled'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_platform_op_status ON platform_operation(status) WHERE status IN ('pending', 'in_progress');
CREATE INDEX IF NOT EXISTS idx_platform_op_tenant ON platform_operation(tenant_id);

COMMENT ON TABLE platform_operation IS 'Async operation orchestration for provisioning, backup, restore, delete.';

-- =============================================================================
-- 6. Audit events (append-only)
-- =============================================================================

CREATE TABLE IF NOT EXISTS platform_audit_event (
    id              BIGSERIAL PRIMARY KEY,
    event_type      TEXT NOT NULL,
    actor_id        UUID NOT NULL,
    actor_email     TEXT NOT NULL,
    target_type     TEXT NOT NULL,
    target_id       TEXT NOT NULL,
    tenant_id       UUID,
    details         JSONB NOT NULL DEFAULT '{}',
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_event_type ON platform_audit_event(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON platform_audit_event(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_tenant ON platform_audit_event(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON platform_audit_event(created_at);

COMMENT ON TABLE platform_audit_event IS 'Append-only audit log for all platform admin operations. No UPDATE or DELETE.';

-- =============================================================================
-- 7. Support tickets
-- =============================================================================

CREATE TABLE IF NOT EXISTS support_ticket (
    id              SERIAL PRIMARY KEY,
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    reported_by     UUID NOT NULL REFERENCES users(id),
    subject         TEXT NOT NULL,
    description     TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'open',
    priority        TEXT NOT NULL DEFAULT 'normal',
    assigned_to     UUID REFERENCES users(id),
    resolved_at     TIMESTAMPTZ,
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'support_ticket' AND constraint_name = 'support_ticket_status_check'
    ) THEN
        ALTER TABLE support_ticket
            ADD CONSTRAINT support_ticket_status_check
            CHECK (status IN ('open', 'in_progress', 'resolved', 'closed'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_support_tenant ON support_ticket(tenant_id);
CREATE INDEX IF NOT EXISTS idx_support_status ON support_ticket(status);

COMMENT ON TABLE support_ticket IS 'Support tickets raised by tenant users. Requires a response (not optional like feedback).';

-- =============================================================================
-- 8. Backup management
-- =============================================================================

CREATE TABLE IF NOT EXISTS backup_history (
    id              SERIAL PRIMARY KEY,
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    backup_type     TEXT NOT NULL,
    file_path       TEXT NOT NULL,
    file_size_bytes BIGINT,
    storage_location TEXT DEFAULT 'local',
    google_drive_id TEXT,
    status          TEXT NOT NULL DEFAULT 'in_progress',
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    triggered_by    TEXT,
    error_message   TEXT
);

CREATE INDEX IF NOT EXISTS idx_backup_tenant ON backup_history(tenant_id);

CREATE TABLE IF NOT EXISTS backup_schedule (
    id              SERIAL PRIMARY KEY,
    tenant_id       UUID NOT NULL UNIQUE REFERENCES tenants(id),
    cron_expression TEXT NOT NULL DEFAULT '0 2 * * *',
    retention_count INT DEFAULT 7,
    retention_days  INT DEFAULT 30,
    enabled         BOOLEAN NOT NULL DEFAULT true,
    last_run_at     TIMESTAMPTZ,
    next_run_at     TIMESTAMPTZ
);

COMMENT ON TABLE backup_history IS 'History of all tenant database backups with storage location and status.';
COMMENT ON TABLE backup_schedule IS 'Per-tenant backup schedule configuration.';
