-- Platform schema: shared services database (ledgius_platform).
-- Contains authentication, tenant registry, subscriptions, and user-tenant mappings.
-- This schema lives in its own database, separate from all tenant databases.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. Tenants
-- =============================================================================

CREATE TABLE IF NOT EXISTS tenants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    abn             TEXT NULL,
    legal_name      TEXT NULL,
    db_name         TEXT NOT NULL UNIQUE,
    db_host         TEXT NOT NULL DEFAULT 'localhost',
    db_port         INT NOT NULL DEFAULT 5436,
    status          TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('provisioning', 'active', 'suspended', 'cancelled')),
    default_currency TEXT NOT NULL DEFAULT 'AUD',
    fiscal_year_start_month INT NOT NULL DEFAULT 7,
    timezone        TEXT NOT NULL DEFAULT 'Australia/Sydney',
    gst_registered  BOOLEAN NOT NULL DEFAULT false,
    gst_registration_date DATE NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE tenants IS 'Registry of all tenant organisations. Each tenant has its own PostgreSQL database.';
COMMENT ON COLUMN tenants.slug IS 'URL-safe identifier, e.g. janes-consulting';
COMMENT ON COLUMN tenants.db_name IS 'PostgreSQL database name, e.g. ledgius_t_janes_consulting';
COMMENT ON COLUMN tenants.abn IS 'Australian Business Number (11 digits)';
COMMENT ON COLUMN tenants.fiscal_year_start_month IS 'Month the fiscal year starts (7 = July for AU)';

CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants(status);

-- =============================================================================
-- 2. Users (platform-level authentication)
-- =============================================================================

CREATE TABLE IF NOT EXISTS users (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email             TEXT NOT NULL UNIQUE,
    password_hash     TEXT NOT NULL,
    display_name      TEXT NOT NULL,
    is_platform_admin BOOLEAN NOT NULL DEFAULT false,
    status            TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'deactivated')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE users IS 'Platform user accounts. Authentication is centralised; authorisation is per-tenant via tenant_memberships.';
COMMENT ON COLUMN users.is_platform_admin IS 'Service operator flag — can manage all tenants, knowledge pipeline, rules engine';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash. Never exposed via API.';

-- =============================================================================
-- 3. Tenant Memberships (user-tenant-role mapping)
-- =============================================================================

CREATE TABLE IF NOT EXISTS tenant_memberships (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    role        TEXT NOT NULL DEFAULT 'viewer'
        CHECK (role IN ('owner', 'master_accountant', 'accountant', 'bookkeeper', 'viewer')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, tenant_id)
);

COMMENT ON TABLE tenant_memberships IS 'Maps users to tenants with a role. One user can access multiple tenants (org switcher).';
COMMENT ON COLUMN tenant_memberships.role IS 'owner: full control. master_accountant: accounting + admin. accountant: full accounting ops. bookkeeper: data entry. viewer: read-only.';

CREATE INDEX IF NOT EXISTS idx_tenant_memberships_user ON tenant_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_tenant_memberships_tenant ON tenant_memberships(tenant_id);

-- =============================================================================
-- 4. Tenant Groups (optional: link tenants for org-switcher convenience)
-- =============================================================================

CREATE TABLE IF NOT EXISTS tenant_groups (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    created_by  UUID NOT NULL REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tenant_group_members (
    group_id    UUID NOT NULL REFERENCES tenant_groups(id) ON DELETE CASCADE,
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, tenant_id)
);

COMMENT ON TABLE tenant_groups IS 'Groups multiple tenants for users who manage several businesses (e.g. partnership + sole trader)';

-- =============================================================================
-- 5. Refresh Tokens
-- =============================================================================

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    tenant_id   UUID NULL REFERENCES tenants(id) ON DELETE CASCADE,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE refresh_tokens IS 'Hashed refresh tokens for JWT rotation. Old tokens are invalidated on use.';
COMMENT ON COLUMN refresh_tokens.tenant_id IS 'The tenant this token was issued for. Null = no tenant selected yet.';

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens(expires_at);

-- =============================================================================
-- 6. Audit Log (platform-level)
-- =============================================================================

CREATE TABLE IF NOT EXISTS platform_audit_log (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID NULL REFERENCES users(id),
    tenant_id   UUID NULL REFERENCES tenants(id),
    action      TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   TEXT NULL,
    detail_json JSONB NULL,
    ip_address  TEXT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE platform_audit_log IS 'Immutable audit trail for platform-level actions (tenant creation, user management, subscription changes)';

CREATE INDEX IF NOT EXISTS idx_audit_log_user ON platform_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_tenant ON platform_audit_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON platform_audit_log(created_at);
