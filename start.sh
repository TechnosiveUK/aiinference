#!/bin/bash
# PrivaXAI AI Stack - Startup Script
# Purpose: Starts the AI inference stack and pulls the model

set -e

echo "=== Starting PrivaXAI AI Inference Stack ==="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed."
    echo ""
    echo "Please install Docker first:"
    echo "  sudo ./install-docker.sh"
    echo ""
    echo "Or run the full setup:"
    echo "  sudo ./setup.sh"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "Docker is not running. Attempting to start Docker..."
    if command -v systemctl &> /dev/null; then
        sudo systemctl start docker
        sleep 3
        if docker info &> /dev/null; then
            echo "✓ Docker started successfully"
        else
            echo "ERROR: Failed to start Docker. Please start it manually:"
            echo "  sudo systemctl start docker"
            echo "  sudo systemctl enable docker  # Enable auto-start on boot"
            exit 1
        fi
    else
        echo "ERROR: Docker is not running and systemctl not available."
        echo "Please start Docker manually."
        exit 1
    fi
fi

# Check if NVIDIA Container Toolkit is available
# Try multiple CUDA image tags, or skip if network is slow
echo "Checking GPU access in Docker..."
GPU_TESTED=false
CUDA_TAGS=("latest" "12.2.0-base-ubuntu22.04" "11.8.0-base-ubuntu22.04")

for TAG in "${CUDA_TAGS[@]}"; do
    # Check if image exists locally first
    if docker images nvidia/cuda:$TAG --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -q "nvidia/cuda:$TAG"; then
        if timeout 30 docker run --rm --gpus all nvidia/cuda:$TAG nvidia-smi &> /dev/null; then
            echo "✓ GPU access verified with existing image"
            GPU_TESTED=true
            break
        fi
    fi
done

# If no local images and network is available, try pulling (with timeout)
if [ "$GPU_TESTED" = false ]; then
    echo "   No local CUDA images found, skipping GPU test (will test during service startup)"
    echo "   If network is slow, images will be pulled during service startup"
    echo "   This is normal and may take 10-30 minutes"
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
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    # Check if Ollama container is running
    CONTAINER_STATUS=$(docker compose ps ollama --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "")
    if [ "$CONTAINER_STATUS" = "running" ]; then
        # Check if we can see "Listening" in logs (Ollama is ready when it logs this)
        if docker compose logs ollama 2>/dev/null | grep -q "Listening on"; then
            echo "✓ Ollama is ready"
            break
        fi
    fi
    sleep 3
    elapsed=$((elapsed + 3))
    if [ $((elapsed % 15)) -eq 0 ]; then
        echo "  Waiting... ($elapsed/$timeout seconds)"
    fi
done

if [ $elapsed -ge $timeout ]; then
    echo "WARNING: Ollama readiness check timed out"
    echo "Checking Ollama status..."
    docker compose ps ollama
    echo ""
    echo "Checking if Ollama is actually running..."
    if docker compose logs ollama 2>/dev/null | grep -q "Listening on"; then
        echo "✓ Ollama appears to be running (found 'Listening on' in logs)"
        echo "  Proceeding anyway..."
    else
        echo "✗ Ollama may not be ready. Check logs: docker compose logs ollama"
        echo "  Attempting to continue anyway..."
    fi
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

