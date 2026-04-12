-- Spec references: R-0047.
-- Task completion evidence records.

-- Add metadata column to calendar_task for task-type-specific context
ALTER TABLE calendar_task ADD COLUMN IF NOT EXISTS task_category TEXT DEFAULT 'general';
ALTER TABLE calendar_task ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';
COMMENT ON COLUMN calendar_task.task_category IS 'Category for completion verification: recon, payroll, bas, invoices, bills, super, general';
COMMENT ON COLUMN calendar_task.metadata IS 'Task-type-specific context, e.g. {"chart_id": 1010} for bank recon tasks';

-- Completion evidence table
CREATE TABLE IF NOT EXISTS task_completion_record (
    id              BIGSERIAL PRIMARY KEY,
    task_id         BIGINT NOT NULL REFERENCES calendar_task(id),
    completed_by    TEXT NOT NULL,
    completed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completion_mode TEXT NOT NULL CHECK (completion_mode IN ('auto_verified', 'manual')),
    completion_note TEXT,
    checklist_state JSONB DEFAULT '[]',
    activity_trail  JSONB DEFAULT '[]',
    verification_evidence JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE task_completion_record IS 'Immutable completion evidence for calendar tasks. One record per completion — forms part of the audit trail.';
COMMENT ON COLUMN task_completion_record.task_id IS 'Foreign key to calendar_task. Each task has at most one completion record.';
COMMENT ON COLUMN task_completion_record.completed_by IS 'Email of the user who completed the task.';
COMMENT ON COLUMN task_completion_record.completed_at IS 'Timestamp when the task was marked complete.';
COMMENT ON COLUMN task_completion_record.completion_mode IS 'auto_verified = system detected work was done; manual = user provided evidence.';
COMMENT ON COLUMN task_completion_record.completion_note IS 'Required for manual completions (min 10 chars). Null for auto-verified tasks.';
COMMENT ON COLUMN task_completion_record.checklist_state IS 'JSONB array of checklist items and their ticked/unticked state at completion time.';
COMMENT ON COLUMN task_completion_record.activity_trail IS 'JSONB array of captured user actions during the task session (pages visited, buttons clicked, etc.).';
COMMENT ON COLUMN task_completion_record.verification_evidence IS 'System-generated proof for auto-verified tasks, e.g. {"report_id": 42, "end_date": "2026-04-11", "matched_count": 47}.';

CREATE INDEX IF NOT EXISTS idx_task_completion_task_id ON task_completion_record(task_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_task_completion_unique ON task_completion_record(task_id) WHERE completion_mode = 'auto_verified';
