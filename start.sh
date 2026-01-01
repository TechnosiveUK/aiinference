#!/bin/bash
# PrivaXAI AI Stack - Startup Script
# Purpose: Starts the AI inference stack and pulls the model

set -e

echo "=== Starting PrivaXAI AI Inference Stack ==="
echo ""

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "ERROR: Docker is not running. Please start Docker first."
    exit 1
fi

# Check if NVIDIA Container Toolkit is available
if ! docker run --rm --gpus all nvidia/cuda:latest nvidia-smi &> /dev/null; then
    echo "ERROR: GPU not accessible in Docker. Run ./setup.sh first."
    exit 1
fi

# Start services
echo "1. Starting Docker Compose services..."
docker compose up -d

echo "2. Waiting for services to be healthy..."
sleep 10

# Wait for ClickHouse to be ready and initialize
echo "3. Waiting for ClickHouse to be ready..."
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker compose exec -T clickhouse clickhouse-client --query "SELECT 1" &> /dev/null; then
        echo "✓ ClickHouse is ready"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo "  Waiting... ($elapsed/$timeout seconds)"
done

if [ $elapsed -lt $timeout ]; then
    echo "4. Initializing ClickHouse database and tables..."
    docker compose exec -T clickhouse clickhouse-client < config/clickhouse/init.sql
    echo "✓ ClickHouse initialized"
    
    # Initialize usage queries and views
    echo "5. Initializing usage queries and views..."
    docker compose exec -T clickhouse clickhouse-client < config/clickhouse/usage_queries.sql 2>/dev/null || echo "   (Usage queries may already exist)"
    echo "✓ Usage queries initialized"
else
    echo "WARNING: ClickHouse did not become ready in time, skipping initialization"
fi

# Wait for Ollama to be ready
echo "6. Waiting for Ollama to be ready..."
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if docker compose exec -T ollama curl -f http://localhost:11434/api/tags &> /dev/null; then
        echo "✓ Ollama is ready"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo "  Waiting... ($elapsed/$timeout seconds)"
done

if [ $elapsed -ge $timeout ]; then
    echo "ERROR: Ollama did not become ready in time"
    docker compose logs ollama
    exit 1
fi

# Pull Qwen 2.5 Coder 7B model
echo "7. Pulling Qwen 2.5 Coder 7B model (this may take several minutes)..."
echo "   Model size: ~4.4GB"
docker compose exec -T ollama ollama pull qwen2.5-coder:7b

if [ $? -eq 0 ]; then
    echo "✓ Model pulled successfully"
else
    echo "ERROR: Failed to pull model"
    exit 1
fi

# Verify model is available
echo "8. Verifying model..."
MODELS=$(docker compose exec -T ollama ollama list)
if echo "$MODELS" | grep -q "qwen2.5-coder:7b"; then
    echo "✓ Model verified"
else
    echo "WARNING: Model not found in list"
    echo "$MODELS"
fi

echo ""
echo "=== Stack Started Successfully ==="
echo ""
echo "Services:"
echo "  - Ollama: http://localhost:11434 (internal only)"
echo "  - TensorZero Gateway: http://localhost:8000 (for PrivaXAI platform)"
echo "  - ClickHouse: http://localhost:8123 (internal only)"
echo ""
echo "Run ./verify.sh to verify all services"
echo "Run ./stop.sh to stop the stack"
echo ""

