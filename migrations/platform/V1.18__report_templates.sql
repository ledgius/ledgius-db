-- Spec references: R-0071 (RT-006, RT-007, RT-008), A-0042, T-0033-01.
--
-- V1.18 — Report templates, template versions, and generation log.
-- Templates are stored as JSONB and belong to a tenant (or NULL for system defaults).

-- =============================================================================
-- 1. Report Templates
-- =============================================================================

CREATE TABLE IF NOT EXISTS report_templates (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID REFERENCES tenants(id) ON DELETE CASCADE,
    name              TEXT NOT NULL,
    description       TEXT,
    data_source       TEXT NOT NULL,
    category          TEXT NOT NULL DEFAULT 'custom'
        CHECK (category IN ('financial', 'customer', 'vendor', 'compliance', 'payroll', 'custom')),
    template_json     JSONB NOT NULL DEFAULT '{"root":{},"content":[],"zones":{}}',
    page_size         TEXT NOT NULL DEFAULT 'A4'
        CHECK (page_size IN ('A4', 'A4-landscape', 'Letter', 'Letter-landscape', 'Legal')),
    page_orientation  TEXT NOT NULL DEFAULT 'portrait'
        CHECK (page_orientation IN ('portrait', 'landscape')),
    page_margins      JSONB NOT NULL DEFAULT '{"top": 15, "right": 15, "bottom": 15, "left": 15}',
    is_default        BOOLEAN NOT NULL DEFAULT false,
    is_active         BOOLEAN NOT NULL DEFAULT true,
    version           INT NOT NULL DEFAULT 1,
    created_by        UUID REFERENCES users(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE report_templates IS
    'Report layout templates. Puck editor JSON defines component positions, '
    'data bindings, and formatting. tenant_id=NULL for system defaults.';
COMMENT ON COLUMN report_templates.data_source IS
    'The data source this template is designed for (e.g. profit_loss, invoice, customer_statement).';
COMMENT ON COLUMN report_templates.template_json IS
    'Puck editor JSON output — captures complete layout: components, positions, sizes, bindings.';
COMMENT ON COLUMN report_templates.is_default IS
    'System-provided templates are read-only (is_default=true, tenant_id=NULL). Users clone to customise.';

CREATE INDEX IF NOT EXISTS idx_report_templates_tenant
    ON report_templates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_report_templates_data_source
    ON report_templates(data_source);

-- =============================================================================
-- 2. Template Versions (history)
-- =============================================================================

CREATE TABLE IF NOT EXISTS report_template_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id     UUID NOT NULL REFERENCES report_templates(id) ON DELETE CASCADE,
    version         INT NOT NULL,
    template_json   JSONB NOT NULL,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (template_id, version)
);

COMMENT ON TABLE report_template_versions IS
    'Version history for report templates. Each save creates a new version.';

-- =============================================================================
-- 3. Report Generation Log (audit)
-- =============================================================================

CREATE TABLE IF NOT EXISTS report_generation_log (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    template_id     UUID NOT NULL REFERENCES report_templates(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    data_source     TEXT NOT NULL,
    params          JSONB,
    format          TEXT NOT NULL DEFAULT 'html'
        CHECK (format IN ('html', 'pdf', 'print')),
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE report_generation_log IS
    'Audit log of every report generation — who, what template, when, with what parameters.';

CREATE INDEX IF NOT EXISTS idx_report_gen_log_tenant
    ON report_generation_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_report_gen_log_generated
    ON report_generation_log(generated_at);
