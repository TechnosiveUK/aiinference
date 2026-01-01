#!/bin/bash
# PrivaXAI AI Stack - Verification Script
# Purpose: Verifies all services are running and healthy

set -e

echo "=== PrivaXAI AI Inference Stack Verification ==="
echo ""

# Check if services are running
echo "1. Checking service status..."
docker compose ps
echo ""

# Check GPU usage
echo "2. Checking GPU status..."
nvidia-smi
echo ""

# Test Ollama
echo "3. Testing Ollama..."
if docker compose exec -T ollama curl -f http://localhost:11434/api/tags &> /dev/null; then
    echo "✓ Ollama is responding"
    
    # List models
    echo "   Available models:"
    docker compose exec -T ollama ollama list | sed 's/^/   /'
else
    echo "✗ Ollama is not responding"
fi
echo ""

# Test TensorZero Gateway
echo "4. Testing TensorZero Gateway..."
if curl -f http://localhost:8000/health &> /dev/null; then
    echo "✓ TensorZero Gateway is responding"
    HEALTH=$(curl -s http://localhost:8000/health)
    echo "   Health: $HEALTH"
else
    echo "✗ TensorZero Gateway is not responding"
    echo "   Check logs: docker compose logs tensorzero"
fi
echo ""

# Test ClickHouse
echo "5. Testing ClickHouse..."
if docker compose exec -T clickhouse clickhouse-client --query "SELECT 1" &> /dev/null; then
    echo "✓ ClickHouse is responding"
    
    # Check if database exists
    DB_EXISTS=$(docker compose exec -T clickhouse clickhouse-client --query "EXISTS DATABASE tensorzero" 2>/dev/null || echo "0")
    if [ "$DB_EXISTS" = "1" ]; then
        echo "   Database 'tensorzero' exists"
    else
        echo "   WARNING: Database 'tensorzero' does not exist (will be created on first use)"
    fi
else
    echo "✗ ClickHouse is not responding"
    echo "   Check logs: docker compose logs clickhouse"
fi
echo ""

# Test model inference
echo "6. Testing model inference..."
TEST_RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-tenant-id: test-tenant" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 10
  }' 2>/dev/null || echo "ERROR")

if echo "$TEST_RESPONSE" | grep -q "choices"; then
    echo "✓ Model inference test successful"
    echo "   Response preview: $(echo "$TEST_RESPONSE" | head -c 100)..."
else
    echo "✗ Model inference test failed"
    echo "   Response: $TEST_RESPONSE"
fi
echo ""

# Check resource usage
echo "7. Resource usage:"
echo "   Memory:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | grep -E "NAME|privaxai" || true
echo ""
echo "   GPU Memory:"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | awk '{printf "   GPU: %d MB / %d MB (%.1f%%)\n", $1, $2, ($1/$2)*100}'
echo ""

echo "=== Verification Complete ==="
echo ""
echo "To view logs:"
echo "  docker compose logs -f [service-name]"
echo ""
echo "To test the API:"
echo "  curl -X POST http://localhost:8000/v1/chat/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'x-tenant-id: your-tenant-id' \\"
echo "    -d '{\"model\": \"qwen2.5-coder:7b\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello\"}]}'"
echo ""

