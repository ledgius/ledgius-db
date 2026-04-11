-- Spec references: R-0043, A-0022.
--
-- Financial Calendar — calendar_task table.
-- Stores accountant-injected tasks and manual reminders that appear
-- in the tenant user's financial calendar timeline.

CREATE TABLE IF NOT EXISTS calendar_task (
    id              BIGSERIAL PRIMARY KEY,
    title           TEXT NOT NULL,
    description     TEXT,
    due_date        DATE NOT NULL,
    priority        TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('normal', 'high')),
    status          TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'completed', 'cancelled')),
    link            TEXT,
    created_by      TEXT NOT NULL,
    created_by_role TEXT,
    assigned_to     TEXT,
    completed_at    TIMESTAMPTZ,
    completed_by    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE calendar_task IS 'Accountant/user-injected tasks shown in the financial calendar timeline. Supports collaboration between accountant and tenant users.';
COMMENT ON COLUMN calendar_task.link IS 'Optional relative URL for navigation, e.g. /banking, /bas';
COMMENT ON COLUMN calendar_task.created_by IS 'Email of the user who created the task';
COMMENT ON COLUMN calendar_task.created_by_role IS 'Role of the creator at time of creation (owner, master_accountant, etc.)';
COMMENT ON COLUMN calendar_task.assigned_to IS 'Optional email of the assigned user. Null = visible to all tenant users.';
COMMENT ON COLUMN calendar_task.completed_by IS 'Email of the user who marked the task complete';

CREATE INDEX IF NOT EXISTS idx_calendar_task_due_date ON calendar_task(due_date);
CREATE INDEX IF NOT EXISTS idx_calendar_task_status ON calendar_task(status);
CREATE INDEX IF NOT EXISTS idx_calendar_task_created_by ON calendar_task(created_by);
