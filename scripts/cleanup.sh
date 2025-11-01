#!/bin/bash

# Cleanup script for Bitcoin regtest network
# This script stops and removes all containers and volumes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
cd "$SCRIPT_DIR"

# Detect which docker compose command to use
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Neither 'docker-compose' nor 'docker compose' is available"
    exit 1
fi

echo "Stopping and removing Bitcoin regtest network..."
$DOCKER_COMPOSE -f "$DOCKER_COMPOSE_FILE" down -v

echo "Cleaning up Docker volumes..."
docker volume ls | grep -E "(node1-data|node2-data)" | awk '{print $2}' | xargs -r docker volume rm || true

echo "✅ Cleanup completed!"
