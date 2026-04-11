-- Knowledge Ingestion Pipeline tables for Phase 6.
-- These tables exist ONLY in the Ledgius DB.
-- Reference: docs/architecture/knowledge_ingestion_pipeline_v3.md

-- =============================================================================
-- 1. Taxonomy (section 7)
-- =============================================================================

CREATE TABLE IF NOT EXISTS taxonomy_node (
    id          BIGSERIAL PRIMARY KEY,
    parent_id   BIGINT NULL REFERENCES taxonomy_node(id),
    canonical_key TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    description TEXT NULL,
    level       INT NOT NULL,
    node_type   TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'active',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE taxonomy_node IS 'Controlled hierarchical taxonomy for classifying knowledge artifacts (e.g. tax.gst.classification.taxable_supply)';
COMMENT ON COLUMN taxonomy_node.canonical_key IS 'Dot-separated canonical key, e.g. tax.gst.reporting.bas.g1';
COMMENT ON COLUMN taxonomy_node.node_type IS 'Type of node: domain, category, subcategory, leaf';
COMMENT ON COLUMN taxonomy_node.status IS 'active, proposed, deprecated, merged';

CREATE INDEX IF NOT EXISTS idx_taxonomy_node_parent ON taxonomy_node(parent_id);
CREATE INDEX IF NOT EXISTS idx_taxonomy_node_status ON taxonomy_node(status);

CREATE TABLE IF NOT EXISTS taxonomy_alias (
    id               BIGSERIAL PRIMARY KEY,
    taxonomy_node_id BIGINT NOT NULL REFERENCES taxonomy_node(id),
    alias            TEXT NOT NULL,
    alias_type       TEXT NOT NULL,
    UNIQUE (taxonomy_node_id, alias)
);

COMMENT ON TABLE taxonomy_alias IS 'Alternative names and cross-references for taxonomy nodes';
COMMENT ON COLUMN taxonomy_alias.alias_type IS 'Type of alias: synonym, abbreviation, external_ref, sbr_concept';

-- =============================================================================
-- 2. Schema Registry (section 8)
-- =============================================================================

CREATE TABLE IF NOT EXISTS enumeration (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    values_json JSONB NOT NULL,
    status      TEXT NOT NULL DEFAULT 'active'
);

COMMENT ON TABLE enumeration IS 'Named enumerations referenced by schema fields (e.g. supply_type: taxable, gst_free, input_taxed)';

CREATE TABLE IF NOT EXISTS entity_schema (
    id             BIGSERIAL PRIMARY KEY,
    name           TEXT NOT NULL,
    version        INT NOT NULL,
    schema_kind    TEXT NOT NULL,
    schema_json    JSONB NOT NULL,
    status         TEXT NOT NULL DEFAULT 'draft',
    effective_from TIMESTAMPTZ NOT NULL,
    effective_to   TIMESTAMPTZ NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (name, version)
);

COMMENT ON TABLE entity_schema IS 'Versioned entity schemas that artifacts must bind to (e.g. Transaction v1, BASReport v2)';
COMMENT ON COLUMN entity_schema.schema_kind IS 'Kind: entity, report, tax_treatment, enum_group';
COMMENT ON COLUMN entity_schema.status IS 'draft, active, deprecated, retired';

CREATE TABLE IF NOT EXISTS schema_field (
    id               BIGSERIAL PRIMARY KEY,
    entity_schema_id BIGINT NOT NULL REFERENCES entity_schema(id),
    field_path       TEXT NOT NULL,
    field_name       TEXT NOT NULL,
    field_type       TEXT NOT NULL,
    nullable         BOOLEAN NOT NULL DEFAULT false,
    enum_id          BIGINT NULL REFERENCES enumeration(id),
    description      TEXT NULL,
    UNIQUE (entity_schema_id, field_path)
);

COMMENT ON TABLE schema_field IS 'Individual fields within an entity schema, used for artifact binding validation';
COMMENT ON COLUMN schema_field.field_path IS 'Dot-separated path, e.g. txn.supply_type, invoice.issue_date';
COMMENT ON COLUMN schema_field.field_type IS 'Type: string, int, decimal, bool, date, datetime, enum, array, object';

CREATE INDEX IF NOT EXISTS idx_schema_field_schema ON schema_field(entity_schema_id);

-- =============================================================================
-- 3. Source Registry (section 9)
-- =============================================================================

CREATE TABLE IF NOT EXISTS source_system (
    id               BIGSERIAL PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE,
    authority_level  TEXT NOT NULL,
    base_url         TEXT NOT NULL,
    access_mode      TEXT NOT NULL,
    crawl_policy_json JSONB NOT NULL DEFAULT '{}',
    notes            TEXT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE source_system IS 'Authoritative source systems (ATO, SBR, Federal Register of Legislation, AASB)';
COMMENT ON COLUMN source_system.authority_level IS 'Authority: legislation, regulation, ruling, guidance, standard';
COMMENT ON COLUMN source_system.access_mode IS 'Primary access mode: direct, colly, browser';

CREATE TABLE IF NOT EXISTS source_document (
    id               BIGSERIAL PRIMARY KEY,
    source_system_id BIGINT NOT NULL REFERENCES source_system(id),
    source_url       TEXT NOT NULL,
    canonical_url    TEXT NOT NULL,
    document_family  TEXT NOT NULL,
    document_type    TEXT NOT NULL,
    title            TEXT NULL,
    jurisdiction     TEXT NOT NULL DEFAULT 'AU',
    authority_rank   INT NOT NULL DEFAULT 0,
    published_at     TIMESTAMPTZ NULL,
    effective_from   TIMESTAMPTZ NULL,
    effective_to     TIMESTAMPTZ NULL,
    status           TEXT NOT NULL DEFAULT 'active',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE source_document IS 'Individual documents from source systems with provenance and lifecycle metadata';
COMMENT ON COLUMN source_document.document_family IS 'Family: gst_ruling, tax_determination, legislation, sbr_taxonomy, accounting_standard';
COMMENT ON COLUMN source_document.document_type IS 'Format: html, pdf, xml, xsd, xbrl, csv';
COMMENT ON COLUMN source_document.authority_rank IS 'Higher rank = higher authority. Legislation > ruling > guidance';

CREATE INDEX IF NOT EXISTS idx_source_document_system ON source_document(source_system_id);
CREATE INDEX IF NOT EXISTS idx_source_document_family ON source_document(document_family);
CREATE INDEX IF NOT EXISTS idx_source_document_status ON source_document(status);

CREATE TABLE IF NOT EXISTS source_document_version (
    id                 BIGSERIAL PRIMARY KEY,
    source_document_id BIGINT NOT NULL REFERENCES source_document(id),
    version_no         INT NOT NULL,
    raw_blob_ref       TEXT NOT NULL,
    normalized_text    TEXT NOT NULL,
    structured_json    JSONB NOT NULL DEFAULT '{}',
    content_hash       TEXT NOT NULL,
    http_etag          TEXT NULL,
    http_last_modified TEXT NULL,
    render_mode        TEXT NOT NULL DEFAULT 'direct',
    retrieved_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (source_document_id, version_no)
);

COMMENT ON TABLE source_document_version IS 'Versioned snapshots of source documents with content hash for change detection';
COMMENT ON COLUMN source_document_version.raw_blob_ref IS 'Reference to raw content (file path or object store key)';
COMMENT ON COLUMN source_document_version.render_mode IS 'How content was acquired: direct, colly, browser';

CREATE INDEX IF NOT EXISTS idx_source_doc_version_doc ON source_document_version(source_document_id);
CREATE INDEX IF NOT EXISTS idx_source_doc_version_hash ON source_document_version(content_hash);

CREATE TABLE IF NOT EXISTS source_passage (
    id                          BIGSERIAL PRIMARY KEY,
    source_document_version_id  BIGINT NOT NULL REFERENCES source_document_version(id),
    section_ref                 TEXT NULL,
    anchor_text                 TEXT NULL,
    passage_text                TEXT NOT NULL,
    passage_hash                TEXT NOT NULL,
    start_offset                INT NOT NULL,
    end_offset                  INT NOT NULL,
    confidence                  NUMERIC(5,4) NULL,
    search_vector               TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', passage_text)) STORED
);

COMMENT ON TABLE source_passage IS 'Citation-addressable text segments extracted from source documents';
COMMENT ON COLUMN source_passage.section_ref IS 'Section/subsection reference within the document, e.g. s9-5(1)';
COMMENT ON COLUMN source_passage.confidence IS 'Segmentation confidence score 0.0000 to 1.0000';

CREATE INDEX IF NOT EXISTS idx_source_passage_version ON source_passage(source_document_version_id);
CREATE INDEX IF NOT EXISTS idx_source_passage_hash ON source_passage(passage_hash);
CREATE INDEX IF NOT EXISTS idx_source_passage_search ON source_passage USING GIN(search_vector);

-- =============================================================================
-- 4. Knowledge Statements (section 10)
-- =============================================================================

CREATE TABLE IF NOT EXISTS knowledge_statement (
    id                   BIGSERIAL PRIMARY KEY,
    rule_type            TEXT NOT NULL,
    topic_node_id        BIGINT NOT NULL REFERENCES taxonomy_node(id),
    plain_language       TEXT NOT NULL,
    conditions_json      JSONB NOT NULL DEFAULT '[]',
    outcomes_json        JSONB NOT NULL DEFAULT '[]',
    exceptions_json      JSONB NULL,
    assumptions_json     JSONB NULL,
    explicit_or_inferred TEXT NOT NULL DEFAULT 'explicit',
    semantic_confidence  NUMERIC(5,4) NOT NULL DEFAULT 1.0000,
    legal_risk_level     TEXT NOT NULL DEFAULT 'low',
    authority_rank       INT NOT NULL DEFAULT 0,
    effective_from       TIMESTAMPTZ NULL,
    effective_to         TIMESTAMPTZ NULL,
    status               TEXT NOT NULL DEFAULT 'draft',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE knowledge_statement IS 'Structured statements extracted from source passages — bridge between source material and executable artifacts';
COMMENT ON COLUMN knowledge_statement.rule_type IS 'classification, eligibility, calculation, reporting_mapping, validation, orchestration_hint';
COMMENT ON COLUMN knowledge_statement.explicit_or_inferred IS 'explicit (directly stated in source) or inferred (interpretation). Inferred requires elevated review';
COMMENT ON COLUMN knowledge_statement.legal_risk_level IS 'low, medium, high, critical';

CREATE INDEX IF NOT EXISTS idx_knowledge_statement_topic ON knowledge_statement(topic_node_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_statement_type ON knowledge_statement(rule_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_statement_status ON knowledge_statement(status);

CREATE TABLE IF NOT EXISTS statement_citation (
    knowledge_statement_id BIGINT NOT NULL REFERENCES knowledge_statement(id),
    source_passage_id      BIGINT NOT NULL REFERENCES source_passage(id),
    support_type           TEXT NOT NULL,
    notes                  TEXT NULL,
    PRIMARY KEY (knowledge_statement_id, source_passage_id)
);

COMMENT ON TABLE statement_citation IS 'Links knowledge statements to their supporting source passages';
COMMENT ON COLUMN statement_citation.support_type IS 'primary, supporting, contextual, exception_source';

-- =============================================================================
-- 5. Artifacts (section 11)
-- =============================================================================

CREATE TABLE IF NOT EXISTS artifact (
    id                        BIGSERIAL PRIMARY KEY,
    artifact_type             TEXT NOT NULL,
    artifact_key              TEXT NOT NULL UNIQUE,
    topic_node_id             BIGINT NOT NULL REFERENCES taxonomy_node(id),
    entity_schema_id          BIGINT NOT NULL REFERENCES entity_schema(id),
    version                   INT NOT NULL DEFAULT 1,
    jurisdiction              TEXT NOT NULL DEFAULT 'AU',
    authority_rank            INT NOT NULL DEFAULT 0,
    effective_from            TIMESTAMPTZ NOT NULL,
    effective_to              TIMESTAMPTZ NULL,
    status                    TEXT NOT NULL DEFAULT 'draft',
    review_status             TEXT NOT NULL DEFAULT 'pending',
    execution_ready           BOOLEAN NOT NULL DEFAULT false,
    semantic_confidence       NUMERIC(5,4) NOT NULL DEFAULT 0.0000,
    legal_risk_level          TEXT NOT NULL DEFAULT 'low',
    artifact_text             TEXT NULL,
    artifact_json             JSONB NULL,
    generated_by              TEXT NOT NULL DEFAULT 'system',
    generated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    supersedes_artifact_id    BIGINT NULL REFERENCES artifact(id),
    superseded_by_artifact_id BIGINT NULL REFERENCES artifact(id),
    published_bundle_id       BIGINT NULL,
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE artifact IS 'Executable rule artifacts (CEL expressions, Rego policies, go-rules JSON). Must be source-cited, schema-bound, taxonomy-bound, and reviewed before production use';
COMMENT ON COLUMN artifact.artifact_type IS 'cel, rego, gorules';
COMMENT ON COLUMN artifact.artifact_key IS 'Unique key, e.g. gst.classification.taxable_supply.cel.v1';
COMMENT ON COLUMN artifact.review_status IS 'pending, in_review, approved, rejected, escalated';
COMMENT ON COLUMN artifact.status IS 'draft, active, retired, superseded';
COMMENT ON COLUMN artifact.legal_risk_level IS 'low, medium, high, critical';

CREATE INDEX IF NOT EXISTS idx_artifact_type ON artifact(artifact_type);
CREATE INDEX IF NOT EXISTS idx_artifact_topic ON artifact(topic_node_id);
CREATE INDEX IF NOT EXISTS idx_artifact_schema ON artifact(entity_schema_id);
CREATE INDEX IF NOT EXISTS idx_artifact_status ON artifact(status, review_status);
CREATE INDEX IF NOT EXISTS idx_artifact_effective ON artifact(effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_artifact_supersedes ON artifact(supersedes_artifact_id) WHERE supersedes_artifact_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS artifact_citation (
    artifact_id       BIGINT NOT NULL REFERENCES artifact(id),
    source_passage_id BIGINT NOT NULL REFERENCES source_passage(id),
    citation_role     TEXT NOT NULL,
    notes             TEXT NULL,
    PRIMARY KEY (artifact_id, source_passage_id)
);

COMMENT ON TABLE artifact_citation IS 'Links artifacts to their supporting source passages for provenance';
COMMENT ON COLUMN artifact_citation.citation_role IS 'primary, supporting, exception_basis, authority';

CREATE TABLE IF NOT EXISTS artifact_tag (
    artifact_id BIGINT NOT NULL REFERENCES artifact(id),
    tag         TEXT NOT NULL,
    PRIMARY KEY (artifact_id, tag)
);

COMMENT ON TABLE artifact_tag IS 'Free-form tags for artifact discovery (not used for production classification — use taxonomy for that)';

CREATE TABLE IF NOT EXISTS artifact_taxonomy (
    artifact_id      BIGINT NOT NULL REFERENCES artifact(id),
    taxonomy_node_id BIGINT NOT NULL REFERENCES taxonomy_node(id),
    is_primary       BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (artifact_id, taxonomy_node_id)
);

COMMENT ON TABLE artifact_taxonomy IS 'Many-to-many link between artifacts and taxonomy nodes';

-- =============================================================================
-- 6. Conflict Detection (section 13)
-- =============================================================================

CREATE TABLE IF NOT EXISTS artifact_conflict (
    id            BIGSERIAL PRIMARY KEY,
    artifact_id_1 BIGINT NOT NULL REFERENCES artifact(id),
    artifact_id_2 BIGINT NOT NULL REFERENCES artifact(id),
    conflict_type TEXT NOT NULL,
    detected_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    detail_json   JSONB NOT NULL DEFAULT '{}',
    resolved      BOOLEAN NOT NULL DEFAULT false,
    resolved_at   TIMESTAMPTZ NULL,
    resolution    TEXT NULL
);

COMMENT ON TABLE artifact_conflict IS 'Detected conflicts between artifacts that must be resolved before both can be active';
COMMENT ON COLUMN artifact_conflict.conflict_type IS 'overlapping_applicability, contradictory_output, duplicate_semantics, label_double_count, inconsistent_validation';

CREATE INDEX IF NOT EXISTS idx_artifact_conflict_1 ON artifact_conflict(artifact_id_1);
CREATE INDEX IF NOT EXISTS idx_artifact_conflict_2 ON artifact_conflict(artifact_id_2);
CREATE INDEX IF NOT EXISTS idx_artifact_conflict_unresolved ON artifact_conflict(resolved) WHERE resolved = false;

-- =============================================================================
-- 7. Catalog Search Support (section 16)
-- =============================================================================

CREATE TABLE IF NOT EXISTS artifact_catalog (
    artifact_id         BIGINT PRIMARY KEY REFERENCES artifact(id),
    topic_canonical_key TEXT NOT NULL,
    artifact_family     TEXT NOT NULL,
    entity_name         TEXT NOT NULL,
    entity_version      INT NOT NULL,
    jurisdiction        TEXT NOT NULL,
    effective_range     TSTZRANGE NOT NULL,
    authority_rank      INT NOT NULL,
    semantic_confidence NUMERIC(5,4) NOT NULL,
    review_status       TEXT NOT NULL,
    execution_ready     BOOLEAN NOT NULL,
    search_vector       TSVECTOR NOT NULL
);

COMMENT ON TABLE artifact_catalog IS 'Denormalized search/index view for runtime artifact resolution (section 16)';

CREATE INDEX IF NOT EXISTS idx_artifact_catalog_search ON artifact_catalog USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_artifact_catalog_lookup ON artifact_catalog(artifact_family, jurisdiction, execution_ready);
CREATE INDEX IF NOT EXISTS idx_artifact_catalog_effective ON artifact_catalog USING GIST(effective_range);
