# Deployment Guide - PrivaXAI AI Inference Stack

## ⚠️ Important: Target System

**These scripts are designed for Ubuntu Server 24.04 LTS with NVIDIA T4 GPU.**

Do NOT run these on macOS or Windows. They must be executed on your Ubuntu server.

## Pre-Deployment Checklist

Before deploying, ensure your Ubuntu server has:

- [ ] Ubuntu Server 24.04 LTS installed
- [ ] NVIDIA T4 GPU physically installed
- [ ] NVIDIA drivers installed (version 535 or later)
- [ ] Docker installed
- [ ] Docker Compose (v2) installed
- [ ] Internet connection for pulling Docker images and models
- [ ] At least 50GB free disk space
- [ ] Root/sudo access

## Step 1: Transfer Files to Server

### Option A: Using SCP

```bash
# From your local machine
scp -r "AI Inference Stack" user@your-server-ip:/path/to/destination/
```

### Option B: Using Git

```bash
# On the server
git clone <your-repo-url>
cd "AI Inference Stack"
```

### Option C: Using rsync

```bash
# From your local machine
rsync -avz "AI Inference Stack" user@your-server-ip:/path/to/destination/
```

## Step 2: Initial Setup

**SSH into your Ubuntu server** and navigate to the stack directory:

```bash
cd "/path/to/AI Inference Stack"
```

### Run Setup Script

```bash
sudo ./setup.sh
```

**What this does:**
1. ✅ Validates NVIDIA driver installation (`nvidia-smi`)
2. ✅ Checks GPU model (expects T4)
3. ✅ Verifies Ubuntu version (expects 24.04)
4. ✅ Installs NVIDIA Container Toolkit
5. ✅ Configures Docker for GPU access
6. ✅ Tests GPU access in Docker
7. ✅ Sets up directory permissions

**Expected output:**
```
=== PrivaXAI AI Inference Stack Setup ===

1. Checking NVIDIA driver...
[GPU information from nvidia-smi]
✓ NVIDIA driver detected

Detected GPU: NVIDIA T4
...

=== Setup Complete ===
```

**If setup fails:**
- **NVIDIA driver not found**: Install drivers first:
  ```bash
  sudo apt update
  sudo apt install -y nvidia-driver-535
  sudo reboot
  ```
- **Docker not found**: Install Docker:
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker $USER
  # Log out and back in
  ```

## Step 3: Start the Stack

```bash
./start.sh
```

**What this does:**
1. ✅ Checks Docker is running
2. ✅ Verifies GPU access
3. ✅ Starts all Docker services (Ollama, TensorZero, ClickHouse)
4. ✅ Waits for ClickHouse to be ready
5. ✅ Initializes ClickHouse database and tables
6. ✅ Waits for Ollama to be ready
7. ✅ Pulls Qwen 2.5 Coder 7B model (~4.4GB, first run only)
8. ✅ Verifies model is available

**Expected output:**
```
=== Starting PrivaXAI AI Inference Stack ===

1. Starting Docker Compose services...
[Services starting...]

2. Waiting for services to be healthy...
3. Waiting for ClickHouse to be ready...
✓ ClickHouse is ready
4. Initializing ClickHouse database and tables...
✓ ClickHouse initialized
5. Waiting for Ollama to be ready...
✓ Ollama is ready
6. Pulling Qwen 2.5 Coder 7B model (this may take several minutes)...
   Model size: ~4.4GB
pulling manifest...
downloading...
✓ Model pulled successfully
7. Verifying model...
✓ Model verified

=== Stack Started Successfully ===
```

**First run notes:**
- Model download takes 5-15 minutes depending on internet speed
- Total download size: ~4.4GB
- Subsequent starts are much faster (model is cached)

## Step 4: Verify Everything Works

```bash
./verify.sh
```

**What this does:**
1. ✅ Checks service status (all should be "Up")
2. ✅ Displays GPU status and usage
3. ✅ Tests Ollama API
4. ✅ Lists available models
5. ✅ Tests TensorZero Gateway health endpoint
6. ✅ Tests ClickHouse connectivity
7. ✅ Performs a test inference request
8. ✅ Shows resource usage (memory, GPU)

**Expected output:**
```
=== PrivaXAI AI Inference Stack Verification ===

1. Checking service status...
NAME                STATUS
privaxai-ollama     Up
privaxai-gateway    Up
privaxai-clickhouse Up

2. Checking GPU status...
[GPU information]

3. Testing Ollama...
✓ Ollama is responding
   Available models:
   qwen2.5-coder:7b

4. Testing TensorZero Gateway...
✓ TensorZero Gateway is responding
   Health: {"status":"ok"}

5. Testing ClickHouse...
✓ ClickHouse is responding
   Database 'tensorzero' exists

6. Testing model inference...
✓ Model inference test successful

7. Resource usage:
   Memory: [usage stats]
   GPU Memory: [usage stats]

=== Verification Complete ===
```

## Step 5: Test the API

Once verified, test the API from your PrivaXAI platform or directly:

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-tenant-id: test-tenant" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 100
  }'
```

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
# One-time check
nvidia-smi

# Continuous monitoring
watch -n 1 nvidia-smi
```

### Check Service Status

```bash
docker compose ps
```

## Stopping the Stack

```bash
./stop.sh
```

This gracefully stops all services. Data in `ollama/` and `clickhouse_data/` is preserved.

## Troubleshooting

### Services Won't Start

```bash
# Check Docker status
sudo systemctl status docker

# Check logs
docker compose logs

# Restart Docker
sudo systemctl restart docker
```

### GPU Not Accessible

```bash
# Verify NVIDIA driver
nvidia-smi

# Test GPU in Docker
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi

# Reinstall Container Toolkit if needed
sudo ./setup.sh
```

### Model Won't Load

```bash
# Check Ollama logs
docker compose logs ollama

# Manually pull model
docker compose exec ollama ollama pull qwen2.5-coder:7b

# List models
docker compose exec ollama ollama list
```

### Out of Memory

- Check current usage: `nvidia-smi` and `docker stats`
- Reduce `max_tokens` in API requests
- Lower `max_context` in `config/tensorzero.toml`

### Gateway Not Responding

```bash
# Check gateway logs
docker compose logs tensorzero

# Restart gateway
docker compose restart tensorzero

# Verify Ollama is healthy
docker compose exec ollama curl http://localhost:11434/api/tags
```

## Security Configuration

### Firewall Setup

```bash
# Allow internal network access only
sudo ufw allow from 10.0.0.0/8 to any port 8000
sudo ufw allow from 172.16.0.0/12 to any port 8000
sudo ufw allow from 192.168.0.0/16 to any port 8000

# Deny public access
sudo ufw deny 8000

# Enable firewall
sudo ufw enable
```

### Network Isolation

For complete isolation, edit `docker-compose.yaml`:

```yaml
networks:
  ai-stack-internal:
    driver: bridge
    internal: true  # Complete isolation (requires VPN/proxy)
```

## Next Steps

1. **Configure PrivaXAI Platform**: Point it to `http://your-server-ip:8000`
2. **Set up Reverse Proxy**: Add Nginx/Traefik with authentication
3. **Enable TLS**: Use Let's Encrypt for HTTPS
4. **Monitor Usage**: Check ClickHouse for token usage data
5. **Set up Backups**: Backup `ollama/` and `clickhouse_data/` directories

## Support

For issues:
1. Check logs: `docker compose logs [service]`
2. Run verification: `./verify.sh`
3. Check GPU: `nvidia-smi`
4. Review configuration files

