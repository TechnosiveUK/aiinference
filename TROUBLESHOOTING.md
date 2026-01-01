# Troubleshooting Guide

## Git Ownership Issues

### Problem: "fatal: detected dubious ownership in repository"

This occurs when the repository is owned by a different user (often root) than the current user.

### Solution 1: Fix Ownership (Recommended)

```bash
# Change ownership of the entire directory to your user
sudo chown -R $USER:$USER /opt/aiinference

# Verify ownership
ls -la /opt/aiinference

# Now git commands will work
git pull origin main
```

### Solution 2: Add to Safe Directory (Quick Fix)

```bash
# Add the directory to Git's safe directory list
git config --global --add safe.directory /opt/aiinference

# Now git commands will work
git pull origin main
```

**Note:** Solution 1 is preferred as it ensures proper file permissions for all operations.

## NVIDIA Container Toolkit Installation Issues

### Problem: Repository URL returns HTML 404 page

**Symptoms:**
```
E: Type '<!doctype' is not known on line 1 in source list
E: The list of sources could not be read.
```

**Solution:**
```bash
# Remove broken repository file
sudo rm /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Pull latest fixes
git pull origin main

# Re-run setup
sudo ./setup.sh
```

## Docker Permission Issues

### Problem: "permission denied while trying to connect to the Docker daemon socket"

**Solution:**
```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Verify
docker ps
```

## GPU Not Detected in Docker

### Problem: Docker containers can't access GPU

**Solution:**
```bash
# Verify NVIDIA Container Toolkit is installed
nvidia-container-toolkit --version

# Test GPU access
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi

# If it fails, reinstall Container Toolkit
sudo ./setup.sh
```

## Service Won't Start

### Problem: Docker Compose services fail to start

**Check logs:**
```bash
docker compose logs
docker compose logs ollama
docker compose logs tensorzero
docker compose logs clickhouse
```

**Common fixes:**
```bash
# Restart Docker
sudo systemctl restart docker

# Check disk space
df -h

# Check memory
free -h

# Restart services
docker compose down
docker compose up -d
```

## Model Won't Load

### Problem: Ollama can't load or pull models

**Solution:**
```bash
# Check Ollama logs
docker compose logs ollama

# Manually pull model
docker compose exec ollama ollama pull qwen2.5-coder:7b

# Verify model exists
docker compose exec ollama ollama list

# If disk is full, clean up
docker system prune -a
```

## Out of Memory Errors

### Problem: GPU or system memory exhausted

**Check usage:**
```bash
# GPU memory
nvidia-smi

# System memory
free -h
docker stats
```

**Solutions:**
- Reduce `max_tokens` in API requests
- Lower `max_context` in `config/tensorzero.toml`
- Restart services to free memory
- Close other GPU processes

## Gateway Not Responding

### Problem: TensorZero Gateway returns errors

**Check:**
```bash
# Gateway logs
docker compose logs tensorzero

# Gateway health
curl http://localhost:8000/health

# Verify Ollama is healthy
docker compose exec ollama curl http://localhost:11434/api/tags
```

**Fix:**
```bash
# Restart gateway
docker compose restart tensorzero

# If still failing, restart all services
docker compose restart
```

## Port Already in Use

### Problem: "port is already allocated" error

**Solution:**
```bash
# Find process using port
sudo lsof -i :8000
sudo lsof -i :11434

# Kill process or change port in docker-compose.yaml
```

## ClickHouse Connection Issues

### Problem: Can't connect to ClickHouse

**Solution:**
```bash
# Check ClickHouse status
docker compose exec clickhouse clickhouse-client --query "SELECT 1"

# Check logs
docker compose logs clickhouse

# Restart ClickHouse
docker compose restart clickhouse
```

## Getting Help

1. Check service logs: `docker compose logs [service-name]`
2. Run verification: `./verify.sh`
3. Check GPU: `nvidia-smi`
4. Review configuration files
5. Check this troubleshooting guide

