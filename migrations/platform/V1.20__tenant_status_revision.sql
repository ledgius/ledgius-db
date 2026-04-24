-- Spec references: R-0008, T-0040 (KCS-040, KCS-050, KCS-052).
--
-- V1.20 — Tenant status revision counter for T-0040 page-status
-- cache invalidation.
--
-- The /api/v1/pages/:route/status endpoint computes a per-request
-- ETag that includes the tenant's current status_revision. Mutation
-- hooks (journal post / approval / bank-reconciliation decision /
-- BAS lodge / asset disposal / loan payment) increment this counter
-- on commit so the next status request mints a fresh ETag and clients
-- revalidate.
--
-- Defaults to 0 on existing tenants. Additive migration — no data
-- backfill, no downtime risk.

ALTER TABLE tenants
    ADD COLUMN IF NOT EXISTS status_revision BIGINT NOT NULL DEFAULT 0;

COMMENT ON COLUMN tenants.status_revision IS
    'Monotonically-increasing counter incremented by mutation hooks '
    '(journal post, bank reconciliation, BAS lodgement, asset disposal, '
    'loan payment, approval decision) per T-0040 KCS-050. Forms part of '
    'the per-request ETag on /api/v1/pages/:route/status so clients '
    'revalidate cheaply when a real change occurred and serve cached '
    'responses otherwise.';
