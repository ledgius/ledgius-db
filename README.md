# ledgius-db

Database SQL scripts, migrations, seeding, and chart of accounts for Ledgius.

## Structure

```
tenant/              — Versioned tenant-level migrations (001-016)
platform/            — Platform-level schema (multi-tenant management)
coa/                 — Chart of accounts data (AU locale)
fixtures/            — Seed data sets (looking-good demo data)
seed/                — Go seed runner (loads fixture datasets)
migrate/             — Go migration runner
init-databases.sh    — Bootstrap script (creates schemas, loads COA, applies migrations)
reset-databases.sh   — Destroy and recreate database volumes
```

## Migrations

Tenant migrations are versioned SQL scripts applied in order:

| # | Migration | Purpose |
|---|-----------|---------|
| 001 | bank_import_tables | Bank transaction import staging |
| 002 | knowledge_ingestion_pipeline | Knowledge article storage |
| 003 | taxonomy_seed_data | Taxonomy categories |
| 004 | entity_schema_seed_data | Entity/company/credit account schema |
| 005 | review_bundle_testcase_tables | Knowledge review workflow |
| 006 | products_and_tax_codes | Product catalogue and tax codes |
| 007 | recurring_templates_audit_currency | Recurring schedules, templates, audit, currency |
| 008 | payroll | Employee, pay run, PAYG brackets, super rates |
| 009 | audit_metadata | Audit log metadata fields |
| 010 | contact_status | Contact status management |
| 011 | payg_historical_rates | Historical PAYG tax brackets |
| 012 | import_staging_tables | Data import staging tables |
| 013 | recurring_rrule | RRULE column for recurring schedules |
| 014 | import_batch_import_mode | Import mode column |
| 015 | import_strategy | Import strategy column |
| 016 | user_feedback | Feedback, votes, comments, pulse tables |

## Usage

Applied automatically during `make docker-init` (via init-databases.sh) or manually:

```bash
for f in tenant/*.sql; do
  docker exec -i ledgius-db-main psql -U ledgius -d ledgius < "$f"
done
```
