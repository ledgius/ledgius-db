#!/usr/bin/env bash
set -euo pipefail

# reset-databases.sh
# Destroys both database volumes and re-initialises from scratch.
#
# Usage: ./docker/scripts/reset-databases.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Resetting Ledgius databases ==="
echo "This will destroy all data in both databases."
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "Stopping containers..."
docker compose -f "$DOCKER_DIR/docker-compose.yml" --env-file "$DOCKER_DIR/.env" down -v

echo "Starting fresh containers..."
docker compose -f "$DOCKER_DIR/docker-compose.yml" --env-file "$DOCKER_DIR/.env" up -d

echo "Waiting for services to start..."
sleep 5

echo "Initialising databases..."
"$SCRIPT_DIR/init-databases.sh"
