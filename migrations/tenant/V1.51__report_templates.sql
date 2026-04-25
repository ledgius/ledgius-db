-- Spec references: R-0071, A-0042, T-0033.
--
-- Create report template tables previously managed by GORM auto-migrate.
-- Moved to Flyway so seed migration R__12 can reference them.

-- ── Report templates ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS report_templates (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id        UUID,
    name             TEXT NOT NULL,
    description      TEXT DEFAULT '',
    data_source      TEXT NOT NULL,
    category         TEXT NOT NULL DEFAULT 'custom',
    template_json    JSONB NOT NULL DEFAULT '{}',
    page_size        TEXT NOT NULL DEFAULT 'A4',
    page_orientation TEXT NOT NULL DEFAULT 'portrait',
    page_margins     JSONB,
    is_default       BOOLEAN NOT NULL DEFAULT FALSE,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    version          INT NOT NULL DEFAULT 1,
    created_by       UUID,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE report_templates IS 'Report layout templates stored as Puck JSON. System defaults have tenant_id NULL and is_default TRUE.';
COMMENT ON COLUMN report_templates.template_json IS 'Puck editor data structure: { root, content, zones }.';
COMMENT ON COLUMN report_templates.data_source IS 'Slug of the data source this template renders (e.g. profit_loss, invoice). Determines available fields.';

CREATE INDEX IF NOT EXISTS idx_report_templates_tenant ON report_templates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_report_templates_data_source ON report_templates(data_source);

-- ── Template version history ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS report_template_versions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id   UUID NOT NULL REFERENCES report_templates(id) ON DELETE CASCADE,
    version       INT NOT NULL,
    template_json JSONB NOT NULL DEFAULT '{}',
    created_by    UUID,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE report_template_versions IS 'Historical snapshots of report templates. A new row is created before each template update.';

CREATE INDEX IF NOT EXISTS idx_report_template_versions_template ON report_template_versions(template_id);

-- ── Generation audit log ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS report_generation_log (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    TEXT NOT NULL,
    template_id  TEXT NOT NULL,
    user_id      TEXT NOT NULL,
    data_source  TEXT NOT NULL,
    params       JSONB,
    format       TEXT NOT NULL DEFAULT 'html',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE report_generation_log IS 'Audit trail of every report generation — who ran what template, when, with which parameters.';

CREATE INDEX IF NOT EXISTS idx_report_generation_log_tenant ON report_generation_log(tenant_id);
CREATE INDEX IF NOT EXISTS idx_report_generation_log_template ON report_generation_log(template_id);
