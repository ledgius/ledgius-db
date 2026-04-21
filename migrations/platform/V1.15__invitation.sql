-- Spec references: R-0070 (UI-001 through UI-027).
--
-- V1.15 — Tenant user invitation table.
-- Tracks invitations sent by business owners to add users to their tenant.

CREATE TABLE IF NOT EXISTS invitation (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email           TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'viewer'
        CHECK (role IN ('owner', 'master_accountant', 'accountant', 'bookkeeper', 'viewer')),
    display_name    TEXT,
    token           TEXT NOT NULL UNIQUE,
    status          TEXT NOT NULL DEFAULT 'invited'
        CHECK (status IN ('invited', 'accepted', 'expired', 'revoked')),
    invited_by      UUID NOT NULL REFERENCES users(id),
    expires_at      TIMESTAMPTZ NOT NULL,
    accepted_at     TIMESTAMPTZ,
    accepted_by     UUID REFERENCES users(id),
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invitation_token ON invitation(token);
CREATE INDEX IF NOT EXISTS idx_invitation_tenant ON invitation(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invitation_email ON invitation(email);

COMMENT ON TABLE invitation IS
    'Tracks user invitations to tenants. Created when a business owner '
    'invites someone by email. Fulfilled when the invitee accepts via the '
    'email link. Token expires after 7 days.';
COMMENT ON COLUMN invitation.token IS
    'Single-use UUID token embedded in the invitation email link. '
    'Used to validate the invitee identity on acceptance.';
COMMENT ON COLUMN invitation.status IS
    'invited: email sent, awaiting acceptance. '
    'accepted: invitee accepted, membership created. '
    'expired: token TTL exceeded (7 days). '
    'revoked: owner cancelled before acceptance.';
