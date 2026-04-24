-- Spec references: R-0008 §KNW-PIP-027, T-0039 (KCR-060).
--
-- V1.19 — Tenant context fields for contextual knowledge rendering.
-- Adds registrations that feed the knowledge pipeline's render context:
-- BAS cadence, STP enrolment, payroll cadence, entity type, info-panel
-- preference. The existing gst_registered column stays where it is.
--
-- Defaults are sensible for an existing AU small-business tenant and
-- are explicitly a default-fill (not an assertion of fact). The
-- Business Settings UI lets the tenant admin confirm/correct them.

ALTER TABLE tenants
    ADD COLUMN IF NOT EXISTS bas_cadence         TEXT NOT NULL DEFAULT 'quarterly'
        CHECK (bas_cadence IN ('quarterly', 'monthly', 'yearly', 'none')),
    ADD COLUMN IF NOT EXISTS stp_enabled         BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS payroll_cadence     TEXT NOT NULL DEFAULT 'monthly'
        CHECK (payroll_cadence IN ('weekly', 'fortnightly', 'monthly', 'none')),
    ADD COLUMN IF NOT EXISTS entity_type         TEXT NOT NULL DEFAULT 'company'
        CHECK (entity_type IN ('sole_trader', 'company', 'partnership', 'trust', 'other')),
    ADD COLUMN IF NOT EXISTS info_panels_enabled BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN tenants.bas_cadence IS
    'BAS lodgement cadence. quarterly (most common), monthly (turnover > $20m), '
    'yearly (small voluntary registrants), none (not GST-registered). Feeds the '
    'knowledge render context so BAS content reflects the tenant''s actual schedule.';
COMMENT ON COLUMN tenants.stp_enabled IS
    'Whether this tenant lodges STP. Defaults true — STP is mandatory for most '
    'employers under Phase 2. Tenants with no employees can set false.';
COMMENT ON COLUMN tenants.payroll_cadence IS
    'Ordinary pay-run cadence. weekly, fortnightly, monthly, or none (no payroll). '
    'Drives STP next-due calculations and payroll page context.';
COMMENT ON COLUMN tenants.entity_type IS
    'Legal entity type — sole_trader, company, partnership, trust, other. Drives '
    'CGT-event and tax-return copy on the relevant pages (e.g. discount '
    'availability for individuals vs companies).';
COMMENT ON COLUMN tenants.info_panels_enabled IS
    'Tenant preference — show the step-by-step Info Panel at the top of each '
    'page. Experienced teams can disable for a minimalist UI. Default true.';
