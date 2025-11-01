# Bitcoin Regtest Network

A Docker-based private Bitcoin network (regtest mode) setup with two nodes that can mine blocks and send transactions between each other.

## Overview

This project provides a simple way to set up and run a private Bitcoin test network using Docker. It includes:
- Two Bitcoin Core nodes running in regtest mode
- Automated node connection and synchronization
- Block mining capabilities
- Transaction creation and broadcasting between nodes
- Reusable script that can create new transactions on each run
- **Full observability stack** (Prometheus + Grafana) with custom metrics exporter

## Requirements

- Docker and Docker Compose installed
- Bash shell
- Internet connection (for downloading Docker images)

## Quick Start

1. Clone the repository:
```bash
git clone <repository-url>
cd bitcoin-regtest-network
```

2. Run the script:
```bash
./bitcoin-regtest.sh
```

The script will:
- Start two Bitcoin nodes in Docker containers
- Connect them to form a network
- Mine initial blocks to fund wallets
- Create and broadcast a transaction from node1 to node2
- Mine a confirmation block

## Project Structure

```
bitcoin-regtest-network/
├── docker-compose.yml              # Docker Compose configuration for 2 nodes
├── docker-compose-observability.yml # Monitoring stack
├── bitcoin-regtest.sh              # Main script to run the network
├── start-with-monitoring.sh        # Start network + observability
├── cleanup.sh                      # Clean up everything
├── README.md                       # This file
├── OBSERVABILITY.md                # Observability guide
├── monitoring/                     # Observability components
│   ├── metrics-exporter.py         # Custom Prometheus exporter
│   ├── Dockerfile                  # Exporter Docker image
│   ├── prometheus.yml              # Prometheus config
│   ├── grafana-datasources.yml     # Grafana data source
│   └── bitcoin-dashboard.json      # Grafana dashboard
└── .github/
    └── workflows/
        └── ci-cd.yml               # GitHub Actions CI/CD pipeline
```

## Detailed Usage

### Running the Network

The main script `bitcoin-regtest.sh` handles the complete setup:

```bash
./bitcoin-regtest.sh
```

On first run, it will:
1. Start two Bitcoin Core containers
2. Wait for nodes to be ready
3. Connect the nodes
4. Create wallets
5. Mine 101 initial blocks (to unlock block rewards)
6. Send a transaction from node1 to node2
7. Mine a confirmation block

On subsequent runs, it will:
- Reuse existing containers if they're running
- Check and maintain sufficient balance
- Create a new transaction with a random amount each time
- Mine confirmation blocks

### Stopping the Network

To stop and remove all containers and volumes:

```bash
docker-compose down -v
```

This will completely clean up the network and all blockchain data.

### Interacting with Nodes Manually

You can interact with the nodes directly using `bitcoin-cli`:

**Node 1:**
```bash
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass <command>
```

**Node 2:**
```bash
docker exec bitcoin-node2 bitcoin-cli -regtest -rpcport=18445 -rpcuser=btcuser -rpcpassword=btcpass <command>
```

### Examples

#### Check Blockchain Info
```bash
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getblockchaininfo
```

#### Get Wallet Balance
```bash
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getbalance
docker exec bitcoin-node2 bitcoin-cli -regtest -rpcport=18445 -rpcuser=btcuser -rpcpassword=btcpass getbalance
```

#### Mine Blocks
```bash
# Mine 5 blocks on node1
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass generatetoaddress 5 $(docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getnewaddress)
```

#### Send a Transaction
```bash
# Get receiving address from node2
RECEIVE_ADDR=$(docker exec bitcoin-node2 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getnewaddress)

# Send 1.5 BTC from node1 to node2
TXID=$(docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass sendtoaddress $RECEIVE_ADDR 1.5)

echo "Transaction ID: $TXID"
```

#### View Transaction Details
```bash
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass gettransaction $TXID
```

#### Get Block Count
```bash
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getblockcount
```

## Task Examples

### Mining Blocks

The script automatically mines blocks, but you can also mine manually:

```bash
# Mine 10 blocks and send rewards to a new address on node1
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass generatetoaddress 10 $(docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getnewaddress)
```

In regtest mode, blocks are generated instantly (no proof-of-work required).

### Sending a Transaction

The script automatically sends a transaction each time it runs. You can also send transactions manually:

```bash
# Step 1: Get receiving address from node2
NODE2_ADDR=$(docker exec bitcoin-node2 bitcoin-cli -regtest -rpcport=18445 -rpcuser=btcuser -rpcpassword=btcpass getnewaddress)

# Step 2: Send BTC from node1 to node2
TXID=$(docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass sendtoaddress $NODE2_ADDR 2.5)

# Step 3: Mine a block to confirm the transaction
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass generatetoaddress 1 $(docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getnewaddress)

# Step 4: Verify transaction
docker exec bitcoin-node2 bitcoin-cli -regtest -rpcport=18445 -rpcuser=btcuser -rpcpassword=btcpass gettransaction $TXID
```

### Creating Multiple Transactions

Run the script multiple times to create multiple transactions:

```bash
./bitcoin-regtest.sh  # Creates transaction #1
./bitcoin-regtest.sh  # Creates transaction #2
./bitcoin-regtest.sh  # Creates transaction #3
```

Each run will create a new transaction with a random amount between 0.1 and 5.0 BTC.

## Architecture

### Docker Setup

- **bitcoin-node1**: First Bitcoin node
  - RPC port: 18443
  - P2P port: 18444
  - Wallet: wallet1

- **bitcoin-node2**: Second Bitcoin node
  - RPC port: 18445
  - P2P port: 18446
  - Wallet: wallet2

Both nodes run in the same Docker network (`bitcoin-network`) and are configured with:
- Regtest mode (private test network)
- RPC authentication (btcuser/btcpass)
- Transaction index enabled
- Minimal fallback fee

### Node Connection

Nodes connect using Docker's internal networking. The script discovers each node's IP address and uses `addnode` or `connectnode` RPC calls to establish the peer connection.

## Tradeoffs and Design Decisions

1. **Docker Compose vs Manual Docker Commands**: Used Docker Compose for simplicity and reproducibility. Tradeoff: less control over individual container parameters, but easier to manage and understand.

2. **Fixed RPC Credentials**: Used hardcoded credentials (btcuser/btcpass) for simplicity. In production, these should be environment variables or secrets. Tradeoff: less secure but simpler for local development.

3. **Volume Persistence**: Docker volumes are used to persist blockchain data. Tradeoff: data persists between runs (can be cleaned with `-v` flag), which is useful for testing but requires manual cleanup.

4. **Health Checks**: Implemented Docker health checks to ensure nodes are ready before proceeding. Tradeoff: adds some complexity but improves reliability.

5. **Script Reusability**: Script checks for running containers and reuses them. Tradeoff: allows multiple transaction runs but requires manual cleanup if you want a fresh start.

6. **Random Transaction Amounts**: Each script run creates a transaction with a random amount. Tradeoff: more realistic testing but less predictable for specific test scenarios.

7. **Block Generation Strategy**: Mines 101 blocks initially to unlock block rewards (Bitcoin requires 100 confirmations before spending block rewards). Tradeoff: takes slightly longer on first run but ensures proper funding.

8. **Awk vs bc for Floating Point**: Used `awk` for floating point comparisons instead of `bc` for better portability across systems. Tradeoff: slightly less intuitive syntax but more widely available.

## Troubleshooting

### Nodes won't connect

If nodes fail to connect, check:
```bash
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getpeerinfo
docker exec bitcoin-node2 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getpeerinfo
```

### Port conflicts

If ports 18443-18446 are already in use, modify the port mappings in `docker-compose.yml`.

### Insufficient funds

If you get "insufficient funds" errors, mine more blocks:
```bash
docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass generatetoaddress 50 $(docker exec bitcoin-node1 bitcoin-cli -regtest -rpcuser=btcuser -rpcpassword=btcpass getnewaddress)
```

### Containers won't start

Check Docker logs:
```bash
docker-compose logs bitcoin-node1
docker-compose logs bitcoin-node2
```

## Observability

Want to monitor your Bitcoin network in real-time? Check out the **full observability stack**:

```bash
./start-with-monitoring.sh
```

This starts Prometheus, Grafana, and a custom metrics exporter that exposes:
- Block height and blockchain growth
- Peer connections
- Wallet balances
- And more...

See [OBSERVABILITY.md](OBSERVABILITY.md) for details.

**Access:**
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

## CI/CD

This project includes GitHub Actions workflows for:
- **CI**: Validates bash scripts and Dockerfiles on every push/PR
- **CD**: Runs the full Bitcoin regtest network setup and transaction test

See `.github/workflows/ci-cd.yml` for details.

## License

This project is provided as-is for educational and testing purposes.

## Contributing

Feel free to submit issues and pull requests!

