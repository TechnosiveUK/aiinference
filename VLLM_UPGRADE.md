# Upgrade Path: Ollama → vLLM

**Zero-rewrite upgrade path for better performance on NVIDIA T4**

## Current Architecture (Phase 1 - Ollama)

```
TensorZero Gateway
   ↓
Ollama
   ↓
NVIDIA T4
```

**Pros:**
- Simple setup
- Stable
- MVP-friendly
- Low memory overhead

**Cons:**
- Lower throughput (~1×)
- No batching
- Limited concurrency (~20 users)
- GPU utilization ~60%

## Target Architecture (Phase 2 - vLLM)

```
TensorZero Gateway
   ↓
vLLM
   ↓
NVIDIA T4
```

**Gains:**
- 1.5–2× throughput
- Better concurrency (~40 users)
- Lower latency
- GPU utilization ~85%
- Continuous batching
- PagedAttention optimization

## Performance Comparison (T4 with 7B Model)

| Metric          | Ollama   | vLLM   | Improvement |
| --------------- | -------- | ------ | ----------- |
| Throughput      | 1×       | 1.5–2× | 50–100%     |
| Concurrency     | ~20      | ~40    | 100%        |
| Latency         | Moderate | Lower  | 20–30%      |
| GPU Utilization | ~60%     | ~85%   | 42%         |

## Migration Steps

### Step 1: Add vLLM Service to docker-compose.yaml

Add this service (keep Ollama for now):

```yaml
vllm:
  image: vllm/vllm-openai:latest
  container_name: privaxai-vllm
  restart: unless-stopped
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]
  command: >
    --model Qwen/Qwen2.5-Coder-7B-Instruct
    --gpu-memory-utilization 0.90
    --max-model-len 8192
    --tensor-parallel-size 1
    --dtype half
  volumes:
    - ./logs/vllm:/var/log/vllm
  networks:
    - ai-stack-internal
  expose:
    - "8000"
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 120s
```

### Step 2: Update TensorZero Configuration

Change only the model provider URL:

```toml
[models.qwen2.5-coder-7b]
name = "qwen-2.5-coder-7b"
provider = "vllm"  # Changed from "ollama"
base_url = "http://vllm:8000/v1"  # Changed from "http://ollama:11434"
```

**That's it!** Everything else stays identical.

### Step 3: Test vLLM Service

```bash
# Start vLLM service
docker compose up -d vllm

# Wait for model to load (takes 2-3 minutes)
docker compose logs -f vllm

# Test vLLM directly
curl http://localhost:8000/v1/models
```

### Step 4: Switch Gateway to vLLM

```bash
# Update tensorzero.toml
# Change base_url to vllm

# Restart gateway
docker compose restart tensorzero

# Verify
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: test" \
  -d '{"model": "qwen-2.5-coder-7b", "messages": [{"role": "user", "content": "test"}]}'
```

### Step 5: Remove Ollama (Optional)

Once vLLM is stable:

```yaml
# Comment out or remove ollama service from docker-compose.yaml
# ollama:
#   ...
```

## vLLM Configuration Tuning for T4

### Memory Optimization

```yaml
command: >
  --model Qwen/Qwen2.5-Coder-7B-Instruct
  --gpu-memory-utilization 0.90  # Use 90% of 16GB VRAM
  --max-model-len 8192           # Max context length
  --tensor-parallel-size 1       # Single GPU
  --dtype half                    # FP16 for memory efficiency
  --max-num-batched-tokens 8192  # Batch size
```

### Performance Tuning

```yaml
command: >
  --enable-prefix-caching         # Cache prompts
  --max-num-seqs 256             # Max concurrent sequences
  --swap-space 4                  # CPU swap for overflow
```

## Rollback Plan

If vLLM causes issues:

1. **Revert tensorzero.toml** - Change base_url back to Ollama
2. **Restart gateway** - `docker compose restart tensorzero`
3. **Stop vLLM** - `docker compose stop vllm`

No data loss, no downtime (if both services run simultaneously).

## Monitoring During Migration

Watch these metrics:

```bash
# GPU utilization
watch -n 1 nvidia-smi

# Service logs
docker compose logs -f vllm tensorzero

# Request latency
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/v1/chat/completions ...

# Error rates
docker compose logs tensorzero | grep -i error
```

## Cost-Benefit Analysis

### vLLM Benefits
- **2× throughput** = Serve 2× more users with same GPU
- **Better utilization** = Lower cost per request
- **Lower latency** = Better user experience

### vLLM Costs
- **Higher memory usage** = Less headroom for larger models
- **More complex** = Harder to debug
- **Longer startup** = 2-3 minutes vs 30 seconds

### Recommendation

**Upgrade to vLLM when:**
- You have >15 concurrent users regularly
- You need better latency
- You're ready to optimize GPU utilization

**Stay with Ollama if:**
- You have <10 concurrent users
- Simplicity is more important than performance
- You're still in MVP phase

## Key Insight

👉 **TensorZero is the decoupling layer**

This architectural decision allows you to swap inference engines with **zero code changes** in PrivaXAI platform. Only configuration changes needed.

## Complete docker-compose.yaml with vLLM

See `docker-compose.vllm.yaml` for a complete example with both Ollama and vLLM services.

