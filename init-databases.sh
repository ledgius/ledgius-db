#!/usr/bin/env bash
set -euo pipefail

# init-databases.sh
# Bootstraps both legacy and Ledgius databases with the LedgerSMB schema
# and loads the Australian chart of accounts.
# Run this after `docker compose up -d` to set up the databases.
#
# Usage: ./docker/scripts/init-databases.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DOCKER_DIR")"

# Load environment
set -a
source "$DOCKER_DIR/.env"
set +a

AU_COA="./locale/coa/au/General.xml"

echo "=== Ledgius Database Initialisation ==="
echo ""

# Wait for databases to be ready
echo "[1/6] Waiting for databases..."
until docker exec ledgius-db-legacy pg_isready -U "$POSTGRES_USER" -d postgres > /dev/null 2>&1; do
    sleep 1
done
echo "  Legacy DB: ready"

until docker exec ledgius-db-main pg_isready -U "$POSTGRES_USER" -d postgres > /dev/null 2>&1; do
    sleep 1
done
echo "  Ledgius DB: ready"

# Drop and recreate the legacy database so ledgersmb-admin can create it fresh
echo ""
echo "[2/6] Bootstrapping legacy database with LedgerSMB schema..."

# Terminate existing connections before dropping
docker exec ledgius-db-legacy psql -U "$POSTGRES_USER" -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$LEGACY_DB_NAME' AND pid <> pg_backend_pid();" 2>/dev/null || true
sleep 1
docker exec ledgius-db-legacy psql -U "$POSTGRES_USER" -d postgres -c \
    "DROP DATABASE IF EXISTS $LEGACY_DB_NAME;" 2>/dev/null

docker exec -e PGHOST=db-legacy -e PGPORT=5432 -e PGUSER="$POSTGRES_USER" -e PGPASSWORD="$POSTGRES_PASSWORD" \
    ledgius-lsmb perl -Ilib -Iold/lib bin/ledgersmb-admin create \
    "${POSTGRES_USER}@db-legacy/${LEGACY_DB_NAME}" 2>&1 | tail -5

echo "  Legacy DB: schema applied"

# Create admin user
echo ""
echo "[3/8] Creating admin user..."

docker exec -e PGHOST=db-legacy -e PGPORT=5432 -e PGUSER="$POSTGRES_USER" -e PGPASSWORD="$POSTGRES_PASSWORD" \
    ledgius-lsmb perl -Ilib -Iold/lib bin/ledgersmb-admin user create \
    "${POSTGRES_USER}@db-legacy/${LEGACY_DB_NAME}" \
    --username "$LSMB_ADMIN_USER" \
    --password "$LSMB_ADMIN_PASSWORD" \
    --first-name Admin \
    --last-name User \
    --country AU \
    --employeenumber EMP-001 \
    --permission "Full Permissions" \
    2>&1 | tail -3

echo "  Admin user: $LSMB_ADMIN_USER (password: $LSMB_ADMIN_PASSWORD)"

# Load Australian chart of accounts into legacy DB
echo ""
echo "[4/8] Loading Australian chart of accounts..."

docker exec -e PGHOST=db-legacy -e PGPORT=5432 -e PGUSER="$POSTGRES_USER" -e PGPASSWORD="$POSTGRES_PASSWORD" \
    ledgius-lsmb perl -Ilib -Iold/lib bin/ledgersmb-admin setup load \
    "${POSTGRES_USER}@db-legacy/${LEGACY_DB_NAME}" "$AU_COA" 2>&1 | tail -5

# Verify COA loaded
ACCT_COUNT=$(docker exec ledgius-db-legacy psql -U "$POSTGRES_USER" -d "$LEGACY_DB_NAME" -tAc \
    "SELECT count(*) FROM account;")
HEADING_COUNT=$(docker exec ledgius-db-legacy psql -U "$POSTGRES_USER" -d "$LEGACY_DB_NAME" -tAc \
    "SELECT count(*) FROM account_heading;")
echo "  Loaded: $ACCT_COUNT accounts, $HEADING_COUNT headings"

# Dump legacy database (schema + data including COA + admin user) and load into Ledgius DB
echo ""
echo "[5/8] Cloning database to Ledgius instance..."
docker exec ledgius-db-legacy pg_dump \
    -U "$POSTGRES_USER" \
    -d "$LEGACY_DB_NAME" \
    --no-owner \
    --no-privileges \
    > /tmp/ledgius_schema_dump.sql

docker exec -i ledgius-db-main psql -U "$POSTGRES_USER" -d "$LEDGIUS_DB_NAME" <<SQL
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO $POSTGRES_USER;
SQL

docker exec -i ledgius-db-main psql \
    -U "$POSTGRES_USER" \
    -d "$LEDGIUS_DB_NAME" \
    < /tmp/ledgius_schema_dump.sql > /dev/null 2>&1

rm -f /tmp/ledgius_schema_dump.sql
echo "  Ledgius DB: cloned from legacy (schema + AU COA)"

# Verify parity
echo ""
echo "[6/8] Verifying parity..."

LEGACY_TABLES=$(docker exec ledgius-db-legacy psql -U "$POSTGRES_USER" -d "$LEGACY_DB_NAME" -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")
LEDGIUS_TABLES=$(docker exec ledgius-db-main psql -U "$POSTGRES_USER" -d "$LEDGIUS_DB_NAME" -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")

LEGACY_ACCTS=$(docker exec ledgius-db-legacy psql -U "$POSTGRES_USER" -d "$LEGACY_DB_NAME" -tAc \
    "SELECT count(*) FROM account;")
LEDGIUS_ACCTS=$(docker exec ledgius-db-main psql -U "$POSTGRES_USER" -d "$LEDGIUS_DB_NAME" -tAc \
    "SELECT count(*) FROM account;")

echo "  Tables:   Legacy=$LEGACY_TABLES Ledgius=$LEDGIUS_TABLES"
echo "  Accounts: Legacy=$LEGACY_ACCTS Ledgius=$LEDGIUS_ACCTS"

PARITY_OK=true
if [ "$LEGACY_TABLES" != "$LEDGIUS_TABLES" ]; then
    echo "  Table count parity: FAIL"
    PARITY_OK=false
fi
if [ "$LEGACY_ACCTS" != "$LEDGIUS_ACCTS" ]; then
    echo "  Account count parity: FAIL"
    PARITY_OK=false
fi

if [ "$PARITY_OK" = true ]; then
    echo "  Parity: PASS"
else
    exit 1
fi

# Apply Ledgius tenant migrations (payroll, recurring, import, etc.)
echo ""
echo "[7/8] Applying Ledgius tenant migrations..."
MIGRATION_DIR="$PROJECT_ROOT/api/migrations/tenant"
if [ -d "$MIGRATION_DIR" ]; then
    MIGRATION_COUNT=0
    for f in "$MIGRATION_DIR"/*.sql; do
        [ -f "$f" ] || continue
        docker exec -i ledgius-db-main psql -U "$POSTGRES_USER" -d "$LEDGIUS_DB_NAME" < "$f" > /dev/null 2>&1
        MIGRATION_COUNT=$((MIGRATION_COUNT + 1))
    done
    echo "  Applied $MIGRATION_COUNT migration files"
else
    echo "  No migration directory found at $MIGRATION_DIR"
fi

echo ""
echo "[8/8] Summary"
echo "  Legacy DB:  postgresql://${POSTGRES_USER}:****@localhost:${LEGACY_DB_PORT}/${LEGACY_DB_NAME}"
echo "  Ledgius DB: postgresql://${POSTGRES_USER}:****@localhost:${LEDGIUS_DB_PORT}/${LEDGIUS_DB_NAME}"
echo "  LedgerSMB:  http://localhost:${LSMB_PORT}/login.pl"
echo "  Setup UI:   http://localhost:${LSMB_PORT}/setup.pl"
echo "  Login:      username=$LSMB_ADMIN_USER password=$LSMB_ADMIN_PASSWORD database=$LEGACY_DB_NAME"
echo "  AU COA:     $ACCT_COUNT accounts, $HEADING_COUNT headings loaded into both databases"
echo ""
echo "=== Initialisation complete ==="
