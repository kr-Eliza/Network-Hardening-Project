#!/bin/bash

echo "[ROLLBACK] Flushing nftables ruleset..."
sudo nft flush ruleset

echo "[ROLLBACK] Re-enabling IPv4 forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1

echo "[ROLLBACK] Current nftables state:"
sudo nft list ruleset

echo "[ROLLBACK] Done. Firewall policy cleared and forwarding kept enabled."