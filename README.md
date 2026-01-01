# PrivaXAI AI Inference Stack

Production-grade, zero-licensing-cost AI inference stack for the PrivaXAI SaaS platform.

## Overview

This stack provides GPU-accelerated LLM inference using:
- **Ollama**: GPU inference engine running Qwen 2.5 Coder 7B
- **TensorZero**: LLM Gateway for routing, observability, and usage tracking
- **ClickHouse**: Telemetry and token usage storage

## Hardware Requirements

- **OS**: Ubuntu Server 24.04 LTS
- **CPU**: 8 cores
- **RAM**: 32 GiB
- **GPU**: NVIDIA T4 (16GB VRAM)
- **Disk**: 50 GiB SSD (minimum)

## Architecture

```
PrivaXAI Platform (External)
    ↓ (Private Network)
TensorZero Gateway (Port 8000) ← Only exposed service
    ↓
    ├─→ Ollama (Port 11434, internal)
    └─→ ClickHouse (Port 8123, internal)
```

**Security**: Ollama and ClickHouse are NOT exposed publicly. Only the TensorZero Gateway is accessible, and it should be behind a reverse proxy or VPN in production.

## Quick Start

### For Fresh Server Deployment

**👉 See [CLEAN_DEPLOYMENT.md](CLEAN_DEPLOYMENT.md) for complete step-by-step instructions**

**Or use [QUICK_START.md](QUICK_START.md) for a copy-paste checklist**

### Quick Commands

```bash
# 1. Initial Setup (Run Once)
sudo ./setup.sh

# 2. Start the Stack
./start.sh

# 3. Verify Everything Works
./verify.sh

# 4. Stop the Stack
./stop.sh
```

## Configuration

### TensorZero Gateway

Configuration: `config/tensorzero.toml`

- Model: Qwen 2.5 Coder 7B
- Max context: 16k tokens
- Default temperature: 0.7
- Rate limiting: 60 RPM, 100k TPM (default)

### Docker Compose

Configuration: `docker-compose.yaml`

- All services use restart policies
- GPU is reserved for Ollama
- Internal networking isolates services
- Health checks ensure reliability

## API Usage

### From PrivaXAI Platform

The TensorZero Gateway exposes an OpenAI-compatible API:

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-tenant-id: your-tenant-id" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "messages": [
      {"role": "user", "content": "Explain compliance requirements"}
    ],
    "max_tokens": 512,
    "temperature": 0.7
  }'
```

### Tenant Identification

Pass tenant ID via header:
```
x-tenant-id: tenant-123
```

This enables future per-tenant rate limiting and usage tracking.

## Security Notes

### Firewall Configuration

**Exposed Ports:**
- `8000`: TensorZero Gateway (internal network only)

**Internal Ports (NOT exposed):**
- `11434`: Ollama
- `8123`: ClickHouse HTTP
- `9000`: ClickHouse native

### Recommended Firewall Rules

```bash
# Allow only internal network access to gateway
sudo ufw allow from 10.0.0.0/8 to any port 8000
sudo ufw allow from 172.16.0.0/12 to any port 8000
sudo ufw allow from 192.168.0.0/16 to any port 8000

# Deny public access
sudo ufw deny 8000
```

### Network Isolation

1. **Private Network**: Deploy PrivaXAI platform and AI stack on the same private network
2. **VPN**: Use VPN for remote access to gateway
3. **Reverse Proxy**: Add Nginx/Traefik in front of gateway with authentication
4. **Internal Network**: Set `internal: true` in docker-compose.yaml for complete isolation

### Production Recommendations

- Add authentication to TensorZero Gateway
- Use TLS/HTTPS for all API calls
- Implement rate limiting per tenant
- Monitor GPU memory usage
- Set up log rotation
- Configure backups for ClickHouse data

## Resource Management

### Memory Limits

- **Ollama**: ~8-12GB RAM (model + inference)
- **ClickHouse**: ~2-4GB RAM
- **TensorZero**: ~500MB RAM
- **System**: ~4GB RAM
- **Total**: ~16-20GB RAM used (within 32GB limit)

### GPU Memory

- **Qwen 2.5 Coder 7B**: ~8-10GB VRAM (quantized)
- **Buffer**: ~4-6GB VRAM
- **Total**: ~12-16GB VRAM (within 16GB T4 limit)

### Disk Usage

- **Model**: ~4.4GB
- **ClickHouse data**: ~1-5GB (grows with usage)
- **Logs**: ~500MB-2GB (rotate regularly)
- **Total**: ~10-15GB (within 50GB limit)

## Monitoring

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f ollama
docker compose logs -f tensorzero
docker compose logs -f clickhouse
```

### Check GPU Usage

```bash
nvidia-smi
watch -n 1 nvidia-smi  # Continuous monitoring
```

### Check Service Health

```bash
# Gateway health
curl http://localhost:8000/health

# Ollama models
docker compose exec ollama ollama list

# ClickHouse status
docker compose exec clickhouse clickhouse-client --query "SELECT 1"
```

## Troubleshooting

### GPU Not Detected

```bash
# Check NVIDIA driver
nvidia-smi

# Verify Container Toolkit
docker run --rm --gpus all nvidia/cuda:latest nvidia-smi

# Reinstall Container Toolkit (if needed)
sudo ./setup.sh
```

### Model Not Loading

```bash
# Check Ollama logs
docker compose logs ollama

# Manually pull model
docker compose exec ollama ollama pull qwen2.5-coder:7b

# Verify model exists
docker compose exec ollama ollama list
```

### Out of Memory

- Reduce `max_tokens` in requests
- Lower `max_context` in tensorzero.toml
- Monitor with `nvidia-smi` and `docker stats`

### Gateway Not Responding

```bash
# Check gateway logs
docker compose logs tensorzero

# Verify Ollama is healthy
docker compose exec ollama curl http://localhost:11434/api/tags

# Restart gateway
docker compose restart tensorzero
```

## Operational Notes

### Model Updates

To update the model:
```bash
docker compose exec ollama ollama pull qwen2.5-coder:7b
docker compose restart tensorzero
```

### Data Persistence

- **Models**: Stored in `ollama/` directory
- **Telemetry**: Stored in `clickhouse_data/` directory
- **Logs**: Stored in `logs/` directory

Backup these directories regularly.

### Scaling Considerations

Current setup supports:
- **Concurrent users**: ~20-30
- **Requests per minute**: ~60 (configurable)
- **Tokens per minute**: ~100k (configurable)

To scale:
1. Add more GPU nodes
2. Switch to vLLM for better throughput
3. Implement per-tenant quotas
4. Add dedicated GPU pools for enterprise tenants

## Migration to Kubernetes

This stack is designed for easy Kubernetes migration:

1. Convert docker-compose.yaml to Kubernetes manifests
2. Use NVIDIA Device Plugin for GPU access
3. Deploy TensorZero, Ollama, and ClickHouse as separate deployments
4. Use ConfigMaps for configuration
5. Use PersistentVolumes for data

## Directory Structure

```
.
├── config/
│   └── tensorzero.toml          # Gateway configuration
├── ollama/                       # Model storage (persistent)
├── clickhouse_data/              # Telemetry data (persistent)
├── logs/                         # Service logs
│   ├── ollama/
│   ├── tensorzero/
│   └── clickhouse/
├── docker-compose.yaml           # Service definitions
├── setup.sh                      # Initial setup script
├── start.sh                      # Start stack
├── stop.sh                       # Stop stack
├── verify.sh                     # Verify services
└── README.md                     # This file
```

## Documentation

See **[DOCUMENTATION.md](DOCUMENTATION.md)** for complete documentation index.

**Quick links:**
- **[QUICK_START.md](QUICK_START.md)** - Quick deployment checklist
- **[CLEAN_DEPLOYMENT.md](CLEAN_DEPLOYMENT.md)** - Complete deployment guide
- **[API_CONTRACT.md](API_CONTRACT.md)** - API specification
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

## Support

For issues or questions:
1. Check logs: `docker compose logs [service]`
2. Run verification: `./verify.sh`
3. Check GPU: `nvidia-smi`
4. Review configuration files
5. See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for detailed solutions

## License

All components are zero-licensing-cost:
- Ollama: MIT License
- TensorZero: Open source
- ClickHouse: Apache 2.0 License

