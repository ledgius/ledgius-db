-- Review tasks, publication bundles, and test cases for the knowledge pipeline.
-- Reference: docs/architecture/knowledge_ingestion_pipeline_v3.md sections 20-22.

-- =============================================================================
-- 1. Test Cases (section 20)
-- =============================================================================

CREATE TABLE IF NOT EXISTS artifact_test_case (
    id              BIGSERIAL PRIMARY KEY,
    artifact_id     BIGINT NOT NULL REFERENCES artifact(id),
    test_class      TEXT NOT NULL,
    description     TEXT NOT NULL,
    input_json      JSONB NOT NULL,
    expected_output JSONB NOT NULL,
    is_generated    BOOLEAN NOT NULL DEFAULT true,
    reviewer_approved BOOLEAN NOT NULL DEFAULT false,
    status          TEXT NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE artifact_test_case IS 'Generated and reviewer-approved test scenarios for artifacts. Every published artifact must have at least one approved test.';
COMMENT ON COLUMN artifact_test_case.test_class IS 'positive_path, negative_path, threshold_edge, date_effective, schema_compatibility, ambiguity, supersession, label_total';
COMMENT ON COLUMN artifact_test_case.is_generated IS 'true if machine-generated, false if hand-written by reviewer';

CREATE INDEX IF NOT EXISTS idx_test_case_artifact ON artifact_test_case(artifact_id);
CREATE INDEX IF NOT EXISTS idx_test_case_class ON artifact_test_case(test_class);

-- =============================================================================
-- 2. Review Tasks (section 21)
-- =============================================================================

CREATE TABLE IF NOT EXISTS review_task (
    id              BIGSERIAL PRIMARY KEY,
    artifact_id     BIGINT NOT NULL REFERENCES artifact(id),
    review_type     TEXT NOT NULL,
    reviewer_role   TEXT NOT NULL,
    assigned_to     TEXT NULL,
    priority        INT NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'open',
    opened_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at       TIMESTAMPTZ NULL,
    due_at          TIMESTAMPTZ NULL
);

COMMENT ON TABLE review_task IS 'Review tasks requiring human approval before an artifact can be published';
COMMENT ON COLUMN review_task.review_type IS 'initial_review, re_review, escalation, legal_review';
COMMENT ON COLUMN review_task.reviewer_role IS 'accounting_tax, engineering, legal';
COMMENT ON COLUMN review_task.status IS 'open, in_progress, completed, cancelled';

CREATE INDEX IF NOT EXISTS idx_review_task_artifact ON review_task(artifact_id);
CREATE INDEX IF NOT EXISTS idx_review_task_status ON review_task(status);
CREATE INDEX IF NOT EXISTS idx_review_task_assigned ON review_task(assigned_to) WHERE assigned_to IS NOT NULL;

CREATE TABLE IF NOT EXISTS review_decision (
    id              BIGSERIAL PRIMARY KEY,
    review_task_id  BIGINT NOT NULL REFERENCES review_task(id),
    reviewer        TEXT NOT NULL,
    decision        TEXT NOT NULL,
    comment         TEXT NULL,
    edits_json      JSONB NULL,
    decided_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE review_decision IS 'Individual review decisions on review tasks';
COMMENT ON COLUMN review_decision.decision IS 'approve, approve_with_edits, reject, request_regeneration, mark_ambiguous, escalate';
COMMENT ON COLUMN review_decision.edits_json IS 'Structured edits applied during approve_with_edits';

CREATE INDEX IF NOT EXISTS idx_review_decision_task ON review_decision(review_task_id);

-- =============================================================================
-- 3. Publication Bundles (section 22)
-- =============================================================================

CREATE TABLE IF NOT EXISTS publication_bundle (
    id                  BIGSERIAL PRIMARY KEY,
    bundle_name         TEXT NOT NULL,
    version             INT NOT NULL,
    description         TEXT NULL,
    status              TEXT NOT NULL DEFAULT 'draft',
    artifact_count      INT NOT NULL DEFAULT 0,
    schema_manifest     JSONB NOT NULL DEFAULT '{}',
    taxonomy_manifest   JSONB NOT NULL DEFAULT '{}',
    provenance_manifest JSONB NOT NULL DEFAULT '{}',
    changelog           TEXT NULL,
    integrity_checksum  TEXT NULL,
    published_at        TIMESTAMPTZ NULL,
    published_by        TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (bundle_name, version)
);

COMMENT ON TABLE publication_bundle IS 'Versioned bundles of published artifacts for deterministic deployment and rollback';
COMMENT ON COLUMN publication_bundle.bundle_name IS 'e.g. gst-core, bas-mapping, payg-withholding, entity-schemas';
COMMENT ON COLUMN publication_bundle.status IS 'draft, published, superseded, rolled_back';
COMMENT ON COLUMN publication_bundle.integrity_checksum IS 'SHA-256 checksum of the bundle contents for tamper detection';

CREATE INDEX IF NOT EXISTS idx_pub_bundle_name ON publication_bundle(bundle_name);
CREATE INDEX IF NOT EXISTS idx_pub_bundle_status ON publication_bundle(status);

CREATE TABLE IF NOT EXISTS bundle_artifact (
    bundle_id   BIGINT NOT NULL REFERENCES publication_bundle(id),
    artifact_id BIGINT NOT NULL REFERENCES artifact(id),
    position    INT NOT NULL DEFAULT 0,
    PRIMARY KEY (bundle_id, artifact_id)
);

COMMENT ON TABLE bundle_artifact IS 'Many-to-many link between bundles and the artifacts they contain';

CREATE INDEX IF NOT EXISTS idx_bundle_artifact_artifact ON bundle_artifact(artifact_id);

-- =============================================================================
-- 4. Pipeline Job Tracking (section 23)
-- =============================================================================

CREATE TABLE IF NOT EXISTS pipeline_job (
    id              BIGSERIAL PRIMARY KEY,
    job_type        TEXT NOT NULL,
    source_system   TEXT NULL,
    document_id     BIGINT NULL REFERENCES source_document(id),
    artifact_id     BIGINT NULL REFERENCES artifact(id),
    bundle_id       BIGINT NULL REFERENCES publication_bundle(id),
    status          TEXT NOT NULL DEFAULT 'pending',
    priority        INT NOT NULL DEFAULT 0,
    attempt         INT NOT NULL DEFAULT 0,
    max_attempts    INT NOT NULL DEFAULT 3,
    input_json      JSONB NOT NULL DEFAULT '{}',
    output_json     JSONB NULL,
    error_message   TEXT NULL,
    quarantined     BOOLEAN NOT NULL DEFAULT false,
    scheduled_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at      TIMESTAMPTZ NULL,
    completed_at    TIMESTAMPTZ NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE pipeline_job IS 'Async pipeline job queue — placeholder for River integration. Tracks all pipeline stage executions.';
COMMENT ON COLUMN pipeline_job.job_type IS 'discover_source_documents, fetch_source_document, parse_source_document, canonicalize_document, extract_passages, extract_knowledge_statements, propose_taxonomy_assignments, synthesize_cel_artifacts, synthesize_rego_artifacts, synthesize_go_rules_artifacts, validate_artifacts, detect_conflicts, generate_test_cases, open_review_tasks, publish_bundle, refresh_source_document, diff_source_versions, retire_superseded_artifacts';
COMMENT ON COLUMN pipeline_job.status IS 'pending, running, completed, failed, quarantined';
COMMENT ON COLUMN pipeline_job.quarantined IS 'true if the job has been moved to quarantine after max_attempts failures';

CREATE INDEX IF NOT EXISTS idx_pipeline_job_type ON pipeline_job(job_type);
CREATE INDEX IF NOT EXISTS idx_pipeline_job_status ON pipeline_job(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_job_document ON pipeline_job(document_id) WHERE document_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pipeline_job_scheduled ON pipeline_job(scheduled_at) WHERE status = 'pending';
