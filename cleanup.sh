#!/bin/bash

# Cleanup script for Bitcoin regtest network
# This script stops and removes all containers and volumes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DOCKER_COMPOSE_FILE="docker-compose.yml"

echo "Stopping and removing Bitcoin regtest network..."
docker-compose -f "$DOCKER_COMPOSE_FILE" down -v

echo "Cleaning up Docker volumes..."
docker volume ls | grep -E "(node1-data|node2-data)" | awk '{print $2}' | xargs -r docker volume rm || true

echo "✓ Cleanup completed!"

