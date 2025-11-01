#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_info "Starting Bitcoin network with observability..."

# Start Bitcoin nodes first
log_info "Starting Bitcoin nodes..."
docker compose -f docker-compose.yml up -d

# Wait a bit for nodes to be ready
sleep 10

# Build and start monitoring stack
log_info "Building custom metrics exporter..."
docker build -t bitcoin-metrics-exporter observability/monitoring/

# Start full stack with monitoring
log_info "Starting monitoring stack..."
docker compose -f observability/docker-compose-observability.yml up -d

# Wait for services to be ready
sleep 15

log_info ""
log_info "=========================================="
log_info "🎉 Everything is running!"
log_info "=========================================="
log_info ""
log_info "📊 Monitoring:"
log_info "  Grafana:    http://localhost:3000"
log_info "    (admin/admin)"
log_info "  Prometheus: http://localhost:9090"
log_info ""
log_info "₿  Bitcoin Nodes:"
log_info "  Node1 RPC:  localhost:18443"
log_info "  Node2 RPC:  localhost:18445"
log_info ""
log_info "Run './scripts/bitcoin-regtest.sh' to start mining and creating transactions"
log_info ""
log_info "To stop: docker compose -f observability/docker-compose-observability.yml down -v"
log_info ""

