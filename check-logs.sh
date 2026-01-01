#!/bin/bash
# Quick script to check service logs

echo "=== Service Status ==="
docker compose ps

echo ""
echo "=== Ollama Logs (last 50 lines) ==="
docker compose logs --tail=50 ollama

echo ""
echo "=== Gateway Logs (last 50 lines) ==="
docker compose logs --tail=50 gateway 2>/dev/null || echo "Gateway not started yet"

echo ""
echo "=== ClickHouse Logs (last 50 lines) ==="
docker compose logs --tail=50 clickhouse

echo ""
echo "=== Usage Service Logs (last 50 lines) ==="
docker compose logs --tail=50 usage-service 2>/dev/null || echo "Usage service not started yet"

