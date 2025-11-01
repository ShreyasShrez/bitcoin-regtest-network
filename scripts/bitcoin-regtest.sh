#!/bin/bash

set -euo pipefail

# Bitcoin Regtest Network Script
# This script sets up a private Bitcoin network with 2 nodes, connects them,
# mines blocks, and sends transactions between them.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
cd "$SCRIPT_DIR"

# Detect which docker compose command to use
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log_error "Neither 'docker-compose' nor 'docker compose' is available"
    exit 1
fi

# Helper function to execute RPC commands
# Note: Both nodes use the same credentials but different RPC ports
# Node1: RPC port 18443 (regtest default)
# Node2: RPC port 18445 (custom to avoid conflicts)
rpc_node1() {
    docker exec bitcoin-node1 bitcoin-cli -regtest -rpcport=18443 -rpcuser=btcuser -rpcpassword=btcpass "$@"
}

rpc_node2() {
    docker exec bitcoin-node2 bitcoin-cli -regtest -rpcport=18445 -rpcuser=btcuser -rpcpassword=btcpass "$@"
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function (optional, can be called manually)
cleanup() {
    log_info "Cleaning up..."
    $DOCKER_COMPOSE -f "$DOCKER_COMPOSE_FILE" down -v 2>/dev/null || true
}

# Handle script termination gracefully
trap 'log_info "Script interrupted. Containers will continue running."; exit 0' INT TERM

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

log_info "Starting Bitcoin regtest network..."

# Check if containers are already running
if docker ps | grep -q bitcoin-node1 && docker ps | grep -q bitcoin-node2; then
    log_info "Nodes are already running, reusing existing containers..."
else
    # Start containers
    log_info "Starting Docker containers..."
    $DOCKER_COMPOSE -f "$DOCKER_COMPOSE_FILE" up -d
fi

# Wait for nodes to be ready
log_info "Waiting for nodes to be ready..."
sleep 5

max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if rpc_node1 getblockchaininfo > /dev/null 2>&1 && rpc_node2 getblockchaininfo > /dev/null 2>&1; then
        log_info "Nodes are ready!"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    log_error "Nodes failed to start in time"
    exit 1
fi

# Get node2's IP address in the Docker network
log_info "Discovering node addresses..."
NODE2_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' bitcoin-node2)
NODE1_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' bitcoin-node1)

log_info "Node1 IP: $NODE1_IP"
log_info "Node2 IP: $NODE2_IP"

# Connect the nodes
log_info "Connecting nodes..."
rpc_node1 addnode "$NODE2_IP:18446" "add" || true
rpc_node2 addnode "$NODE1_IP:18444" "add" || true

# Wait for connection to establish
sleep 3

# Verify connection
PEER_COUNT_NODE1=$(rpc_node1 getconnectioncount)
PEER_COUNT_NODE2=$(rpc_node2 getconnectioncount)

log_info "Node1 peer count: $PEER_COUNT_NODE1"
log_info "Node2 peer count: $PEER_COUNT_NODE2"

if [ "$PEER_COUNT_NODE1" -eq 0 ] && [ "$PEER_COUNT_NODE2" -eq 0 ]; then
    log_warn "Direct connection failed, trying alternative method..."
    # Alternative: use connectnode
    rpc_node1 connectnode "$NODE2_IP:18446" || true
    sleep 3
fi

# Create wallets if they don't exist
log_info "Setting up wallets..."
rpc_node1 createwallet "wallet1" 2>/dev/null || rpc_node1 loadwallet "wallet1" 2>/dev/null || true
rpc_node2 createwallet "wallet2" 2>/dev/null || rpc_node2 loadwallet "wallet2" 2>/dev/null || true

# Generate initial blocks on node1 to create some coins
log_info "Mining initial blocks on node1 to fund the wallet..."
INITIAL_BLOCKS=101
rpc_node1 generatetoaddress "$INITIAL_BLOCKS" "$(rpc_node1 getnewaddress)" > /dev/null

log_info "Mined $INITIAL_BLOCKS blocks on node1"

# Sync nodes
log_info "Syncing nodes..."
sleep 3

# Check balances
NODE1_BALANCE=$(rpc_node1 getbalance 2>/dev/null || echo "0")
NODE2_BALANCE=$(rpc_node2 getbalance 2>/dev/null || echo "0")

log_info "Node1 balance: $NODE1_BALANCE BTC"
log_info "Node2 balance: $NODE2_BALANCE BTC"

# Check if nodes have sufficient balance, if not mine more blocks
MIN_BALANCE=50
# Use awk for floating point comparison (more portable than bc)
# Default to 0 if balance is empty or invalid
NODE1_BALANCE=${NODE1_BALANCE:-0}
NODE2_BALANCE=${NODE2_BALANCE:-0}

if awk "BEGIN {exit !($NODE1_BALANCE < $MIN_BALANCE)}"; then
    log_info "Node1 balance is low, mining more blocks..."
    ADDITIONAL_BLOCKS=50
    rpc_node1 generatetoaddress "$ADDITIONAL_BLOCKS" "$(rpc_node1 getnewaddress)" > /dev/null
    sleep 2
    NODE1_BALANCE=$(rpc_node1 getbalance)
    log_info "Node1 new balance: $NODE1_BALANCE BTC"
fi

if awk "BEGIN {exit !($NODE2_BALANCE < $MIN_BALANCE)}"; then
    log_info "Node2 balance is low, mining more blocks..."
    ADDITIONAL_BLOCKS=50
    rpc_node2 generatetoaddress "$ADDITIONAL_BLOCKS" "$(rpc_node2 getnewaddress)" > /dev/null
    sleep 2
    NODE2_BALANCE=$(rpc_node2 getbalance)
    log_info "Node2 new balance: $NODE2_BALANCE BTC"
fi

# Pick random direction for transaction
DIRECTION=$((RANDOM % 2))

if [ $DIRECTION -eq 0 ]; then
    # Send from node1 to node2
    FROM_NODE="Node1"
    FROM_RPC="rpc_node1"
    TO_ADDRESS=$(rpc_node2 getnewaddress)
    log_info "Node2 receiving address: $TO_ADDRESS"
else
    # Send from node2 to node1
    FROM_NODE="Node2"
    FROM_RPC="rpc_node2"
    TO_ADDRESS=$(rpc_node1 getnewaddress)
    log_info "Node1 receiving address: $TO_ADDRESS"
fi

# Generate a random amount between 0.1 and 5.0 BTC for each transaction
# Seed with current time for better randomness
RANDOM_AMOUNT=$(awk "BEGIN {srand(); printf \"%.6f\", 0.1 + rand() * 4.9}")
SEND_AMOUNT=$RANDOM_AMOUNT

log_info "Sending $SEND_AMOUNT BTC from $FROM_NODE..."
TXID=$($FROM_RPC sendtoaddress "$TO_ADDRESS" "$SEND_AMOUNT")

if [ -z "$TXID" ]; then
    log_error "Failed to send transaction"
    exit 1
fi

log_info "Transaction sent! TXID: $TXID"

# Mine a block to confirm the transaction
log_info "Mining a block to confirm the transaction..."
rpc_node1 generatetoaddress 1 "$(rpc_node1 getnewaddress)" > /dev/null

# Wait for block propagation
sleep 2

# Verify transaction (check from sending node)
TX_INFO=$($FROM_RPC gettransaction "$TXID")
if echo "$TX_INFO" | grep -q "confirmations"; then
    log_info "Transaction confirmed!"
else
    log_warn "Transaction may not be confirmed yet"
fi

# Display final balances
NODE1_FINAL_BALANCE=$(rpc_node1 getbalance)
NODE2_FINAL_BALANCE=$(rpc_node2 getbalance)

log_info "Final balances:"
log_info "  Node1: $NODE1_FINAL_BALANCE BTC"
log_info "  Node2: $NODE2_FINAL_BALANCE BTC"

# Display transaction details
log_info "Transaction details:"
$FROM_RPC gettransaction "$TXID" | head -20

log_info ""
log_info "=========================================="
log_info "Bitcoin regtest network is running!"
log_info "=========================================="
log_info "To interact with the nodes:"
log_info "  Node1: docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass <command>"
log_info "  Node2: docker exec bitcoin-node2 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass <command>"
log_info ""
log_info "To stop the network, run: $DOCKER_COMPOSE -f $DOCKER_COMPOSE_FILE down"
log_info ""

log_info ""
log_info "Script completed successfully!"
log_info "To run again and create another transaction, simply run this script again: ./bitcoin-regtest.sh"
log_info "To stop and clean up the network, run: $DOCKER_COMPOSE -f $DOCKER_COMPOSE_FILE down -v"
log_info ""
