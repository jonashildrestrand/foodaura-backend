#!/usr/bin/env bash
# Run the full MyTAP test suite against a disposable foodaura_test database.
#
# Usage:
#   ./db/test/run_tests.sh                      # auto-detect: local mysql or docker exec
#   DB_HOST=... MARIADB_ROOT_PASSWORD=... ./db/test/run_tests.sh
#
# Requires either:
#   - A mysql/mariadb client in $PATH (uses $DB_HOST:$DB_PORT), or
#   - A running 'mariadb' container from docker-compose (uses docker exec)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load .env if present
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -o allexport
  source "$PROJECT_ROOT/.env"
  set +o allexport
fi

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_PW="${MARIADB_ROOT_PASSWORD:-}"
DB_TEST="foodaura_test"

# Resolve the mysql runner: prefer local client, fall back to docker exec
if command -v mysql &>/dev/null; then
  _MYSQL_CMD="mysql -h $DB_HOST -P $DB_PORT -u root -p${DB_ROOT_PW} --batch"
  mysql_run() { $_MYSQL_CMD "$@"; }
  mysql_pipe() { $_MYSQL_CMD "$1" < "$2"; }
elif command -v mariadb &>/dev/null; then
  _MYSQL_CMD="mariadb -h $DB_HOST -P $DB_PORT -u root -p${DB_ROOT_PW} --batch"
  mysql_run() { $_MYSQL_CMD "$@"; }
  mysql_pipe() { $_MYSQL_CMD "$1" < "$2"; }
else
  # Detect the mariadb container name (works with both docker-compose v1 and v2)
  MARIADB_CONTAINER="$(docker-compose -f "$PROJECT_ROOT/docker-compose.yml" ps -q mariadb 2>/dev/null | head -1)"
  if [[ -z "$MARIADB_CONTAINER" ]]; then
    MARIADB_CONTAINER="$(docker ps --filter "ancestor=mariadb:11" --format "{{.ID}}" | head -1)"
  fi
  if [[ -z "$MARIADB_CONTAINER" ]]; then
    echo "ERROR: No mysql client found and no running MariaDB container detected." >&2
    echo "Start docker-compose or install mysql-client." >&2
    exit 1
  fi
  echo "Using docker exec on container: $MARIADB_CONTAINER"
  # Detect the client binary name inside the container
  if docker exec "$MARIADB_CONTAINER" which mariadb &>/dev/null; then
    _CONTAINER_CLI="mariadb"
  else
    _CONTAINER_CLI="mysql"
  fi
  mysql_run() {
    # $1 = optional db name, remaining = -e "SQL"
    local db="$1"; shift
    docker exec -i "$MARIADB_CONTAINER" $_CONTAINER_CLI -u root -p"${DB_ROOT_PW}" --batch "$db" "$@"
  }
  mysql_pipe() {
    # $1 = db name, $2 = file path
    docker exec -i "$MARIADB_CONTAINER" $_CONTAINER_CLI -u root -p"${DB_ROOT_PW}" --batch "$1" < "$2"
  }
fi

echo "=== Foodaura DB test suite ==="

# Provision a fresh test database
echo "--- Provisioning $DB_TEST"
mysql_run "" -e "DROP DATABASE IF EXISTS \`$DB_TEST\`; CREATE DATABASE \`$DB_TEST\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Apply versioned migrations
echo "--- Applying versioned migrations (V__)"
for f in "$PROJECT_ROOT"/db/migrations/V*.sql; do
  echo "    $(basename "$f")"
  mysql_pipe "$DB_TEST" "$f"
done

# Apply repeatable migrations (except R__99_grants which requires procedures to exist — already applied above)
echo "--- Applying repeatable migrations (R__)"
for f in "$PROJECT_ROOT"/db/migrations/R__*.sql; do
  echo "    $(basename "$f")"
  mysql_pipe "$DB_TEST" "$f"
done

# Install MyTAP
echo "--- Installing MyTAP"
mysql_pipe "$DB_TEST" "$SCRIPT_DIR/mytap.sql"

# Load standing fixtures
echo "--- Loading helpers"
mysql_pipe "$DB_TEST" "$SCRIPT_DIR/helpers.sql"

# Run test files and collect exit codes
FAILED=0
for f in "$SCRIPT_DIR"/*_test.sql; do
  echo "--- $(basename "$f")"
  if ! mysql_pipe "$DB_TEST" "$f"; then
    FAILED=1
  fi
done

if [[ $FAILED -eq 0 ]]; then
  echo ""
  echo "=== All tests passed ==="
else
  echo ""
  echo "=== SOME TESTS FAILED ===" >&2
  exit 1
fi
