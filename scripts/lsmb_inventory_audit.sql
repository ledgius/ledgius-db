-- Spec references: R-0054 (LMT-006, LMT-007), A-0030 §"Audit query".
--
-- LSMB legacy artifact audit — read-only, safe to run in production.
--
-- Run against any tenant or platform DB:
--
--   psql -U ledgius -d <db_name> -f scripts/lsmb_inventory_audit.sql
--
-- Or via the Fly proxy:
--
--   echo "\\i scripts/lsmb_inventory_audit.sql" \
--     | fly ssh console --app ledgius-db -C "psql -U ledgius -d ledgius"
--
-- Output sections:
--   1. All triggers + functions currently present in the DB
--   2. Drift report (TODO: requires inventory ingestion; manual diff for now)
--   3. Completeness summary (TODO: requires inventory ingestion)
--
-- Sections 2 and 3 currently emit raw counts only; full inventory-aware
-- diffing is shipped as part of the lsmb-lint Go program (which can
-- parse lsmb_inventory.md and join against the live DB output). See
-- A-0030 §"Audit query" for the eventual three-section design.

\echo
\echo '=== Section 1a — Triggers in public schema ==='
\echo

SELECT
    c.relname AS table_name,
    t.tgname AS trigger_name,
    p.proname AS function_called,
    CASE
        WHEN t.tgtype & 1 = 1 THEN 'ROW'
        ELSE 'STATEMENT'
    END AS scope,
    CASE
        WHEN t.tgtype & 66 != 0 THEN 'BEFORE'
        WHEN t.tgtype & 64 != 0 THEN 'INSTEAD OF'
        ELSE 'AFTER'
    END AS timing
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE NOT t.tgisinternal
  AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY c.relname, t.tgname;

\echo
\echo '=== Section 1b — Functions in public schema (count by namespace) ==='
\echo

SELECT
    CASE
        WHEN p.proname LIKE '%\\_\\_%' ESCAPE '\\'
            THEN split_part(p.proname, '__', 1)
        ELSE '(unprefixed)'
    END AS namespace,
    COUNT(*) AS function_count
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
GROUP BY 1
ORDER BY function_count DESC, namespace;

\echo
\echo '=== Section 1c — Total artifact counts ==='
\echo

SELECT
    'triggers (non-internal, public schema)' AS artifact_kind,
    COUNT(*) AS count
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE NOT t.tgisinternal
  AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
UNION ALL
SELECT
    'functions (public schema)',
    COUNT(*)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f'
UNION ALL
SELECT
    'views (public schema)',
    COUNT(*)
FROM pg_views
WHERE schemaname = 'public'
UNION ALL
SELECT
    'sequences (public schema)',
    COUNT(*)
FROM pg_sequences
WHERE schemaname = 'public';

\echo
\echo '=== Drift detection ==='
\echo 'For Section 2 (in-DB-not-in-inventory) and Section 3 (completeness%),'
\echo 'use the lsmb-lint Go program which parses lsmb_inventory.md:'
\echo ''
\echo '  go run ./cmd/lsmb-lint --audit --db-url=$DATABASE_URL'
\echo ''
\echo 'See R-0054, A-0030 §"Audit query" for the full design.'
