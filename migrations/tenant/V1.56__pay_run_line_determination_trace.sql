-- Spec references: R-0073, A-0046, T-0041 Slice 6 — Determination Trace.
--
-- Stage 5 of the runtime architecture per A-0046. Captures an immutable
-- per-pay-run-line trace of every authority that contributed to the
-- calculation: which layer (federal/NES/award/EBA/IFA/contract) supplied
-- each value, which CEL formulas were evaluated with which inputs,
-- which authority refs and bundle versions applied.
--
-- The trace is stored as JSONB so the schema can evolve as Slices 7
-- (comparator outcomes) and 8 (exception ledger) extend the trace shape
-- without further DB migrations.
--
-- Per-line, immutable: no updated_at; new traces are inserted on every
-- pay-run calculation. Replay reads the historical trace and re-runs the
-- same inputs through the same authority chain.

CREATE TABLE IF NOT EXISTS pay_run_line_determination_trace (
    id              BIGSERIAL PRIMARY KEY,
    pay_run_line_id INT NOT NULL REFERENCES pay_run_line(id) ON DELETE CASCADE,
    bundle_version  TEXT NOT NULL,
    trace_json      JSONB NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT pay_run_line_determination_trace_one_per_line
        UNIQUE (pay_run_line_id)
);

CREATE INDEX IF NOT EXISTS idx_pay_run_line_determination_trace_line
    ON pay_run_line_determination_trace (pay_run_line_id);

-- GIN index on trace_json for queryability — e.g. "find all lines where
-- the EBA layer supplied the rate" or "find all lines that cited a
-- particular authority ref". Used by audit-handoff queries + the
-- replay endpoint's diff reporter.
CREATE INDEX IF NOT EXISTS idx_pay_run_line_determination_trace_json
    ON pay_run_line_determination_trace USING GIN (trace_json);

COMMENT ON TABLE pay_run_line_determination_trace IS 'Immutable per-pay-run-line audit trace recording the resolved authority chain (federal → NES → award → EBA → IFA → contract layers) plus formula evaluations and inputs. Stage 5 of the A-0046 runtime architecture. Replay re-runs the same inputs through the same chain to verify deterministic reproduction. Dumpable as JSON for FWO/ATO audit handoff.';
COMMENT ON COLUMN pay_run_line_determination_trace.bundle_version IS 'Top-level bundle version stamp (e.g. "MA000004_general_retail_v2026.7.1") for fast filtering. Full version chain for every layer is in trace_json.';
COMMENT ON COLUMN pay_run_line_determination_trace.trace_json IS 'Trace payload. Schema (precursor — extended by Slices 7/8): { trace_version, resolved_layers: [{ component, source, value, authority_ref, bundle_version, formula_name?, inputs? }], envelope: { calculation_version, rounding } }. JSONB for forward-compatibility.';
