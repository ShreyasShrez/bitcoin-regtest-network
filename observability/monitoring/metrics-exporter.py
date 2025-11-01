#!/usr/bin/env python3
"""
Simple Bitcoin metrics exporter for Prometheus
Exposes Bitcoin RPC data as Prometheus metrics
"""

import json
import time
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            metrics = self.get_metrics()
            self.wfile.write(metrics.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def bitcoin_rpc_call(self, method, params=None):
        """Make Bitcoin RPC call via HTTP"""
        if params is None:
            params = []
        
        data = json.dumps({
            "method": method,
            "params": params,
            "id": 1
        }).encode('utf-8')
        
        request = urllib.request.Request(
            'http://bitcoin-node1:18443',
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        # Add basic auth
        import base64
        credentials = base64.b64encode(b'btcuser:btcpass').decode('utf-8')
        request.add_header('Authorization', f'Basic {credentials}')
        
        try:
            with urllib.request.urlopen(request, timeout=5) as response:
                result = json.loads(response.read().decode('utf-8'))
                return result.get('result')
        except Exception as e:
            print(f"RPC error: {e}")
            return None
    
    def get_metrics(self):
        """Get metrics from Bitcoin RPC"""
        metrics = []
        
        try:
            # Get blockchain info
            data = self.bitcoin_rpc_call('getblockchaininfo')
            
            if data:
                # Block height
                metrics.append(f'# HELP bitcoin_block_height Current block height')
                metrics.append(f'# TYPE bitcoin_block_height gauge')
                metrics.append(f'bitcoin_block_height {data.get("blocks", 0)}')
                
                # Chain size
                metrics.append(f'# HELP bitcoin_block_chain_size_bytes Blockchain size in bytes')
                metrics.append(f'# TYPE bitcoin_block_chain_size_bytes gauge')
                metrics.append(f'bitcoin_block_chain_size_bytes {data.get("size_on_disk", 0)}')
                
                # Peers
                peer_count = self.bitcoin_rpc_call('getconnectioncount')
                if peer_count is not None:
                    metrics.append(f'# HELP bitcoin_peer_connections Number of peer connections')
                    metrics.append(f'# TYPE bitcoin_peer_connections gauge')
                    metrics.append(f'bitcoin_peer_connections {peer_count}')
                
                # Balance
                balance = self.bitcoin_rpc_call('getbalance')
                if balance is not None:
                    metrics.append(f'# HELP bitcoin_wallet_balance Wallet balance in BTC')
                    metrics.append(f'# TYPE bitcoin_wallet_balance gauge')
                    metrics.append(f'bitcoin_wallet_balance {balance}')
                
                # Transaction count
                tx_count = self.bitcoin_rpc_call('getrawmempool', [])
                if tx_count is not None:
                    metrics.append(f'# HELP bitcoin_mempool_transactions Number of transactions in mempool')
                    metrics.append(f'# TYPE bitcoin_mempool_transactions gauge')
                    metrics.append(f'bitcoin_mempool_transactions {len(tx_count)}')
                
                # Network info and version
                network_info = self.bitcoin_rpc_call('getnetworkinfo')
                if network_info:
                    metrics.append(f'# HELP bitcoin_version_major Bitcoin Core major version')
                    metrics.append(f'# TYPE bitcoin_version_major gauge')
                    metrics.append(f'bitcoin_version_major {network_info.get("version", 0) // 10000}')
                    
                    # Network connections breakdown
                    metrics.append(f'# HELP bitcoin_network_connections_in Inbound connections')
                    metrics.append(f'# TYPE bitcoin_network_connections_in gauge')
                    metrics.append(f'bitcoin_network_connections_in {network_info.get("connections_in", 0)}')
                    
                    metrics.append(f'# HELP bitcoin_network_connections_out Outbound connections')
                    metrics.append(f'# TYPE bitcoin_network_connections_out gauge')
                    metrics.append(f'bitcoin_network_connections_out {network_info.get("connections_out", 0)}')
                
                # Unspent transaction outputs (UTXOs)
                utxo_info = self.bitcoin_rpc_call('listunspent')
                if utxo_info is not None:
                    metrics.append(f'# HELP bitcoin_utxo_count Number of unspent transaction outputs')
                    metrics.append(f'# TYPE bitcoin_utxo_count gauge')
                    metrics.append(f'bitcoin_utxo_count {len(utxo_info)}')
                
                # Wallet transaction count
                wallet_info = self.bitcoin_rpc_call('getwalletinfo')
                if wallet_info:
                    metrics.append(f'# HELP bitcoin_wallet_transaction_count Total transactions in wallet')
                    metrics.append(f'# TYPE bitcoin_wallet_transaction_count gauge')
                    metrics.append(f'bitcoin_wallet_transaction_count {wallet_info.get("txcount", 0)}')
                    
                    metrics.append(f'# HELP bitcoin_wallet_keypool_size Keypool size')
                    metrics.append(f'# TYPE bitcoin_wallet_keypool_size gauge')
                    metrics.append(f'bitcoin_wallet_keypool_size {wallet_info.get("keypoolsize", 0)}')
                
                # Mempool info
                mempool_info = self.bitcoin_rpc_call('getmempoolinfo')
                if mempool_info:
                    metrics.append(f'# HELP bitcoin_mempool_size_bytes Mempool size in bytes')
                    metrics.append(f'# TYPE bitcoin_mempool_size_bytes gauge')
                    metrics.append(f'bitcoin_mempool_size_bytes {mempool_info.get("bytes", 0)}')
                    
                    metrics.append(f'# HELP bitcoin_mempool_total_fee Total fees in mempool')
                    metrics.append(f'# TYPE bitcoin_mempool_total_fee gauge')
                    metrics.append(f'bitcoin_mempool_total_fee {mempool_info.get("total_fee", 0)}')
                
                # Memory usage
                memory_info = self.bitcoin_rpc_call('getmemoryinfo', ['stats'])
                if memory_info and 'locked' in memory_info:
                    locked = memory_info['locked']
                    metrics.append(f'# HELP bitcoin_memory_used_bytes Memory used in bytes')
                    metrics.append(f'# TYPE bitcoin_memory_used_bytes gauge')
                    metrics.append(f'bitcoin_memory_used_bytes {locked.get("used", 0)}')
                    
                    metrics.append(f'# HELP bitcoin_memory_free_bytes Memory free in bytes')
                    metrics.append(f'# TYPE bitcoin_memory_free_bytes gauge')
                    metrics.append(f'bitcoin_memory_free_bytes {locked.get("free", 0)}')
                    
        except Exception as e:
            metrics.append(f'# Error: {e}')
        
        return '\n'.join(metrics) + '\n'
    
    def log_message(self, format, *args):
        # Suppress access logs
        pass

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 9332), MetricsHandler)
    print('Bitcoin metrics exporter listening on :9332')
    server.serve_forever()

