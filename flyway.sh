#!/usr/bin/env bash
set -euo pipefail

# flyway.sh — Lightweight Flyway-style migration runner for Ledgius.
# Applies versioned (V*.sql) and repeatable (R__*.sql) scripts in order.
# Tracks applied migrations in flyway_schema_history table.
#
# Usage:
#   ./flyway.sh migrate   [tenant|platform]  — Apply pending migrations
#   ./flyway.sh status    [tenant|platform]  — Show migration status
#   ./flyway.sh validate  [tenant|platform]  — Verify all applied
#   ./flyway.sh reset     [tenant|platform]  — Drop and recreate (DESTRUCTIVE)
#
# Environment:
#   DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME — connection params
#   Or: DATABASE_URL — full connection string
#
# Spec references: A-0021.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-ledgius}"
DB_PASSWORD="${DB_PASSWORD:-ledgius_dev_password}"
DB_NAME="${DB_NAME:-ledgius}"

ACTION="${1:-migrate}"
TRACK="${2:-tenant}"

MIGRATION_DIR="$SCRIPT_DIR/migrations/$TRACK"

if [ ! -d "$MIGRATION_DIR" ]; then
  echo "ERROR: Migration directory not found: $MIGRATION_DIR"
  exit 1
fi

export PGPASSWORD="$DB_PASSWORD"
PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

# ── Ensure history table exists ──
ensure_history_table() {
  $PSQL -q <<'SQL'
CREATE TABLE IF NOT EXISTS flyway_schema_history (
    installed_rank  SERIAL PRIMARY KEY,
    version         TEXT,
    description     TEXT NOT NULL,
    type            TEXT NOT NULL CHECK (type IN ('SQL', 'REPEATABLE')),
    script          TEXT NOT NULL,
    checksum        TEXT,
    installed_by    TEXT NOT NULL DEFAULT current_user,
    installed_on    TIMESTAMPTZ NOT NULL DEFAULT now(),
    execution_time  INT NOT NULL DEFAULT 0,
    success         BOOLEAN NOT NULL DEFAULT true
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_flyway_script ON flyway_schema_history(script);
SQL
}

# ── Compute checksum ──
file_checksum() {
  md5sum "$1" | cut -d' ' -f1
}

# ── Apply versioned scripts ──
apply_versioned() {
  local applied=0
  for script in "$MIGRATION_DIR"/V*.sql; do
    [ -f "$script" ] || continue
    local basename=$(basename "$script")
    local version=$(echo "$basename" | sed 's/^V\([0-9.]*\)__.*/\1/')
    local description=$(echo "$basename" | sed 's/^V[0-9.]*__\(.*\)\.sql/\1/' | tr '_' ' ')
    local checksum=$(file_checksum "$script")

    # Check if already applied
    local existing=$($PSQL -tAc "SELECT checksum FROM flyway_schema_history WHERE script = '$basename' AND success = true;" 2>/dev/null || echo "")

    if [ -n "$existing" ]; then
      if [ "$existing" != "$checksum" ]; then
        echo "  ERROR: Checksum mismatch for $basename (applied: $existing, current: $checksum)"
        echo "         Versioned scripts must not be modified after deployment."
        exit 1
      fi
      continue
    fi

    echo "  Applying: $basename ..."
    local start_s=$(date +%s)
    if $PSQL -q < "$script"; then
      local end_s=$(date +%s)
      local duration=$((end_s - start_s))
      $PSQL -q -c "INSERT INTO flyway_schema_history (version, description, type, script, checksum, execution_time, success) VALUES ('$version', '$description', 'SQL', '$basename', '$checksum', $duration, true);"
      applied=$((applied + 1))
    else
      $PSQL -q -c "INSERT INTO flyway_schema_history (version, description, type, script, checksum, execution_time, success) VALUES ('$version', '$description', 'SQL', '$basename', '$checksum', 0, false);"
      echo "  FAILED: $basename"
      exit 1
    fi
  done
  echo "  Versioned: $applied applied"
}

# ── Apply repeatable scripts ──
apply_repeatable() {
  local applied=0
  for script in "$MIGRATION_DIR"/R__*.sql; do
    [ -f "$script" ] || continue
    local basename=$(basename "$script")
    local description=$(echo "$basename" | sed 's/^R__\(.*\)\.sql/\1/' | tr '_' ' ')
    local checksum=$(file_checksum "$script")

    # Check if already applied with same checksum
    local existing=$($PSQL -tAc "SELECT checksum FROM flyway_schema_history WHERE script = '$basename' AND success = true;" 2>/dev/null || echo "")

    if [ "$existing" = "$checksum" ]; then
      continue
    fi

    echo "  Applying: $basename ..."
    local start_s=$(date +%s)
    if $PSQL -q < "$script"; then
      local end_s=$(date +%s)
      local duration=$((end_s - start_s))
      if [ -n "$existing" ]; then
        $PSQL -q -c "UPDATE flyway_schema_history SET checksum = '$checksum', execution_time = $duration, installed_on = now(), success = true WHERE script = '$basename';"
      else
        $PSQL -q -c "INSERT INTO flyway_schema_history (description, type, script, checksum, execution_time, success) VALUES ('$description', 'REPEATABLE', '$basename', '$checksum', $duration, true);"
      fi
      applied=$((applied + 1))
    else
      echo "  FAILED: $basename"
      exit 1
    fi
  done
  echo "  Repeatable: $applied applied"
}

# ── Status ──
show_status() {
  ensure_history_table
  echo ""
  echo "=== Migration Status: $DB_NAME ($TRACK) ==="
  echo ""
  $PSQL -c "SELECT installed_rank, coalesce(version, '-') as version, type, script, success, installed_on FROM flyway_schema_history ORDER BY installed_rank;"

  # Show pending
  echo ""
  echo "--- Pending ---"
  local pending=0
  for script in "$MIGRATION_DIR"/V*.sql "$MIGRATION_DIR"/R__*.sql; do
    [ -f "$script" ] || continue
    local basename=$(basename "$script")
    local checksum=$(file_checksum "$script")
    local existing=$($PSQL -tAc "SELECT checksum FROM flyway_schema_history WHERE script = '$basename' AND success = true;" 2>/dev/null || echo "")

    if [ -z "$existing" ] || { [[ "$basename" == R__* ]] && [ "$existing" != "$checksum" ]; }; then
      echo "  PENDING: $basename"
      pending=$((pending + 1))
    fi
  done
  if [ "$pending" -eq 0 ]; then
    echo "  (none)"
  fi
}

# ── Validate ──
validate() {
  ensure_history_table
  local errors=0
  for script in "$MIGRATION_DIR"/V*.sql; do
    [ -f "$script" ] || continue
    local basename=$(basename "$script")
    local checksum=$(file_checksum "$script")
    local existing=$($PSQL -tAc "SELECT checksum FROM flyway_schema_history WHERE script = '$basename' AND success = true;" 2>/dev/null || echo "")

    if [ -z "$existing" ]; then
      echo "  NOT APPLIED: $basename"
      errors=$((errors + 1))
    elif [ "$existing" != "$checksum" ]; then
      echo "  CHECKSUM MISMATCH: $basename"
      errors=$((errors + 1))
    fi
  done

  if [ "$errors" -eq 0 ]; then
    echo "  Validation: PASS"
  else
    echo "  Validation: FAIL ($errors errors)"
    exit 1
  fi
}

# ── Reset (DESTRUCTIVE) ──
do_reset() {
  echo "WARNING: This will DROP and recreate database $DB_NAME"
  echo "Press Ctrl+C to abort, or Enter to continue..."
  read -r

  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 <<SQL
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME OWNER $DB_USER;
SQL

  echo "  Database $DB_NAME recreated."
  ensure_history_table
  apply_versioned
  apply_repeatable
  echo ""
  echo "=== Reset complete ==="
}

# ── Main ──
case "$ACTION" in
  migrate)
    echo "=== Flyway Migrate: $DB_NAME ($TRACK) ==="
    ensure_history_table
    apply_versioned
    apply_repeatable
    echo "=== Done ==="
    ;;
  status)
    show_status
    ;;
  validate)
    echo "=== Flyway Validate: $DB_NAME ($TRACK) ==="
    validate
    ;;
  reset)
    do_reset
    ;;
  *)
    echo "Usage: $0 {migrate|status|validate|reset} [tenant|platform]"
    exit 1
    ;;
esac
