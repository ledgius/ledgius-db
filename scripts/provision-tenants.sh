#!/usr/bin/env bash
set -euo pipefail

# provision-tenants.sh
#
# Read every active tenant from ledgius_platform.tenants and ensure that
# tenant has a working PostgreSQL database with all migrations applied.
#
# This closes the gap between `make seed-load DATASET=test-tenants` (which
# only registers tenants in the platform DB) and a working multi-tenant
# environment (which needs each tenant's own database to exist).
#
# Idempotent: skips tenants whose database already exists.
#
# Usage:
#   scripts/provision-tenants.sh                 # all active tenants
#   scripts/provision-tenants.sh --slug=test-farm  # one tenant by slug
#   scripts/provision-tenants.sh --dry-run         # show what would run
#
# Environment (override defaults via env or via Makefile):
#   DB_HOST       (default: localhost)
#   DB_PORT       (default: 5436)
#   DB_USER       (default: ledgius)
#   DB_PASSWORD   (default: ledgius_dev_password)
#   PLATFORM_DB   (default: ledgius_platform)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_REPO="$(dirname "$SCRIPT_DIR")"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5436}"
DB_USER="${DB_USER:-ledgius}"
DB_PASSWORD="${DB_PASSWORD:-ledgius_dev_password}"
PLATFORM_DB="${PLATFORM_DB:-ledgius_platform}"

ONLY_SLUG=""
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --slug=*) ONLY_SLUG="${arg#--slug=}" ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            sed -n '1,30p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

export PGPASSWORD="$DB_PASSWORD"
PSQL_PLATFORM="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $PLATFORM_DB -tAv ON_ERROR_STOP=1"
PSQL_POSTGRES="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -v ON_ERROR_STOP=1"

# ── Pull tenants from the platform DB ──

QUERY="SELECT slug, db_name FROM tenants WHERE status = 'active'"
if [ -n "$ONLY_SLUG" ]; then
    QUERY="$QUERY AND slug = '$ONLY_SLUG'"
fi
QUERY="$QUERY ORDER BY slug;"

# Use a temp file + while-read for compatibility with macOS bash 3.2 (no mapfile).
TENANTS_TMP="$(mktemp)"
trap 'rm -f "$TENANTS_TMP"' EXIT
$PSQL_PLATFORM -c "$QUERY" > "$TENANTS_TMP"

TENANT_COUNT=$(grep -c '|' "$TENANTS_TMP" 2>/dev/null || echo 0)
if [ "$TENANT_COUNT" -eq 0 ]; then
    echo "No active tenants found in $PLATFORM_DB.tenants${ONLY_SLUG:+ matching slug=$ONLY_SLUG}." >&2
    echo "Run 'make seed-load DATASET=test-tenants' first to register tenants." >&2
    exit 1
fi

echo "Provisioning $TENANT_COUNT tenant(s) on $DB_HOST:$DB_PORT"
echo

CREATED=0
SKIPPED_EXISTS=0
MIGRATED=0
FAILED=0

while IFS='|' read -r SLUG DB_NAME; do

    [ -z "$SLUG" ] && continue
    [ -z "$DB_NAME" ] && DB_NAME="$SLUG"

    echo "── $SLUG (db: $DB_NAME)"

    # 1. Create the database if it doesn't exist.
    EXISTS=$($PSQL_POSTGRES -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" 2>/dev/null || echo "")
    if [ "$EXISTS" = "1" ]; then
        echo "    database exists — skipping CREATE"
        SKIPPED_EXISTS=$((SKIPPED_EXISTS + 1))
    else
        if [ "$DRY_RUN" = true ]; then
            echo "    [dry-run] CREATE DATABASE \"$DB_NAME\" OWNER $DB_USER"
        else
            $PSQL_POSTGRES -c "CREATE DATABASE \"$DB_NAME\" OWNER $DB_USER" >/dev/null
            echo "    database created"
            CREATED=$((CREATED + 1))
        fi
    fi

    # 2. Apply tenant migrations via the existing flyway runner.
    if [ "$DRY_RUN" = true ]; then
        echo "    [dry-run] DB_NAME=$DB_NAME ./flyway.sh migrate tenant"
        continue
    fi

    # Capture flyway output so we can verify whether the failure is fatal.
    MIG_LOG="$(mktemp)"
    if DB_HOST="$DB_HOST" DB_PORT="$DB_PORT" DB_USER="$DB_USER" DB_PASSWORD="$DB_PASSWORD" DB_NAME="$DB_NAME" \
        "$DB_REPO/flyway.sh" migrate tenant > "$MIG_LOG" 2>&1; then
        echo "    migrations applied"
        MIGRATED=$((MIGRATED + 1))
    else
        # A repeatable-only failure leaves all versioned migrations applied.
        # Verify that situation before flagging as fatal.
        FAILED_VERSIONED=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
            "SELECT count(*) FROM flyway_schema_history WHERE success=false AND type='SQL'" 2>/dev/null || echo "?")
        if [ "$FAILED_VERSIONED" = "0" ]; then
            echo "    versioned migrations applied; one or more repeatable seeds failed (pre-existing — see log)"
            MIGRATED=$((MIGRATED + 1))
        else
            echo "    MIGRATION FAILED — see log:"
            sed 's/^/      /' "$MIG_LOG" | tail -5
            echo "    re-run with: DB_HOST=$DB_HOST DB_PORT=$DB_PORT DB_NAME=$DB_NAME $DB_REPO/flyway.sh migrate tenant"
            FAILED=$((FAILED + 1))
        fi
    fi
    rm -f "$MIG_LOG"
done < "$TENANTS_TMP"

echo
echo "== Summary =="
echo "  databases created:  $CREATED"
echo "  databases existing: $SKIPPED_EXISTS"
echo "  migrations applied: $MIGRATED"
if [ "$FAILED" -gt 0 ]; then
    echo "  FAILURES:           $FAILED"
    exit 1
fi
