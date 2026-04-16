# Ledgius DB — Claude Code Project Guide

## Project Overview

Database SQL scripts, migrations, seeding, and chart of accounts for Ledgius.

- **Organisation**: `github.com/ledgius`
- **Specs**: `github.com/ledgius/ledgius-specs`

## Structure

```
tenant/              — Versioned tenant-level migrations (001-016+)
platform/            — Platform-level schema (multi-tenant management)
coa/                 — Chart of accounts data (AU and other locales)
fixtures/            — Seed data sets
seed/                — Go seed runner
migrate/             — Go migration runner
init-databases.sh    — Bootstrap script
reset-databases.sh   — Destroy and recreate volumes
```

## Migration Conventions

### Script Types
- **Versioned**: `VN__<name>.sql` — numbered sequentially (001, 002, ...)
- **Repeatable**: `R__<name>.sql` — for views or functions that can be re-run

### Script Completeness
- Make scripts re-entrant where possible (`IF NOT EXISTS`, check constraints before creating)
- **Every table, every column, and every index must have a `COMMENT ON ...` statement.** No exceptions. Table comments explain the table's role and invariants. Column comments explain meaning/purpose and include example data where appropriate. Index comments explain what query pattern the index supports.
- Consider rollback implications
- Evaluate indexing impact for new tables/columns

### Naming
- Use snake_case for all database objects
- Tables: plural nouns (`employees`, `pay_runs`)
- Columns: descriptive, prefixed where needed (`source_code`, `mapped_to_id`)
- Indexes: `idx_<table>_<column(s)>`
- Constraints: descriptive (`recurring_schedule_frequency_check`)

### Data Types
- Monetary values: `NUMERIC` (never `FLOAT` or `DOUBLE PRECISION`)
- Dates: `DATE` for date-only, `TIMESTAMPTZ` for timestamps (always with timezone)
- JSON: `JSONB` (not `JSON`)
- Booleans: `BOOLEAN NOT NULL DEFAULT false`
- Text: `TEXT` (not `VARCHAR` unless there's a specific length constraint)

### Migration Versioning
- Scan all migrations to find the latest version number before creating a new one
- Never modify an existing versioned migration that has been applied to any environment
- New migrations must be additive — don't drop columns or tables without a migration plan

## Seed Data

- `fixtures/datasets/looking-good/` — demo data for development
- Load via: `go run ./seed/ --dataset=looking-good --action=load`
- Unload via: `go run ./seed/ --dataset=looking-good --action=unload`

## Chart of Accounts

- `coa/au/General.xml` — Australian general COA (primary)
- Other locales available but AU is the default for Ledgius
