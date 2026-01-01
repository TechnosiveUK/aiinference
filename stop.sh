#!/bin/bash
# PrivaXAI AI Stack - Stop Script
# Purpose: Stops all services gracefully

set -e

echo "=== Stopping PrivaXAI AI Inference Stack ==="
echo ""

docker compose down

echo "✓ Stack stopped"
echo ""
echo "Note: Data in ollama/ and clickhouse_data/ is preserved"
echo "Run ./start.sh to start again"
echo ""

