-- Spec references: A-0023.
--
-- V1.39 — Action snooze table
--
-- Allows users to acknowledge/snooze Books Overview action items
-- (e.g. "I've chased these overdue invoices, remind me in 7 days").
-- The action reappears after the snooze period if the underlying
-- issue is still unresolved.

CREATE TABLE IF NOT EXISTS action_snooze (
    id              SERIAL PRIMARY KEY,
    action_key      TEXT NOT NULL,
    snoozed_until   TIMESTAMPTZ NOT NULL,
    snoozed_by      TEXT,
    note            TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_action_snooze_key
    ON action_snooze (action_key);

CREATE INDEX IF NOT EXISTS idx_action_snooze_active
    ON action_snooze (action_key, snoozed_until);

COMMENT ON TABLE action_snooze IS
    'Snooze/acknowledge records for Books Overview action items. '
    'An action_key like "overdue_invoices" is snoozed until a timestamp. '
    'The health check excludes snoozed actions from the panel.';

COMMENT ON COLUMN action_snooze.action_key IS
    'Identifier for the action: overdue_invoices, overdue_bills, missing_receipts, etc.';
COMMENT ON COLUMN action_snooze.snoozed_until IS
    'Action reappears after this timestamp if still unresolved.';
COMMENT ON COLUMN action_snooze.note IS
    'Optional note from the user (e.g. "Sent reminders to all 3 customers").';
