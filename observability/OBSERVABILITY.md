# Observability Setup

This project includes a full observability stack for monitoring the Bitcoin regtest network.

## What's Included

- **Prometheus**: Time-series database for metrics
- **Grafana**: Visualization dashboards
- **Custom Metrics Exporter**: Python-based exporter that scrapes Bitcoin RPC data

## Quick Start

Start everything with monitoring:

```bash
./start-with-monitoring.sh
```

This will:
1. Start Bitcoin nodes
2. Build custom metrics exporter
3. Start Prometheus and Grafana
4. Display access URLs

## Access Points

Once running, you can access:

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Metrics Exporter**: http://localhost:9332/metrics

## Metrics Exposed

Our custom exporter scrapes:

- `bitcoin_block_height`: Current blockchain height
- `bitcoin_block_chain_size_bytes`: Size of blockchain on disk
- `bitcoin_peer_connections`: Number of connected peers
- `bitcoin_wallet_balance`: Total wallet balance in BTC

## Grafana Dashboard

The included dashboard shows:
- Block height over time
- Blockchain size growth
- Peer connection count
- Block validation times

## Architecture

```
Bitcoin Nodes (bitcoin-cli)
           ↓
Custom Python Exporter (:9332)
           ↓
Prometheus (:9090)
           ↓
Grafana (:3000)
```

## Customization

Edit `monitoring/metrics-exporter.py` to add more metrics. It uses subprocess to call bitcoin-cli and parse JSON responses.

## Stopping

```bash
docker-compose -f docker-compose-observability.yml down -v
```

