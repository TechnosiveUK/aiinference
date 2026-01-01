# Clean Deployment Guide - PrivaXAI AI Inference Stack

**Complete step-by-step guide for fresh Ubuntu Server 24.04 LTS with NVIDIA T4 GPU**

## Prerequisites

Your Ubuntu server must have:
- ✅ Ubuntu Server 24.04 LTS installed
- ✅ NVIDIA T4 GPU physically installed
- ✅ Internet connection
- ✅ At least 50GB free disk space
- ✅ Root/sudo access

---

## Step 1: Install NVIDIA Drivers (If Not Already Installed)

```bash
# Update package list
sudo apt update

# Install NVIDIA drivers (use latest available version)
sudo apt install -y nvidia-driver-535

# Reboot to load drivers
sudo reboot
```

**After reboot, verify:**
```bash
nvidia-smi
```

You should see your T4 GPU information. If not, check driver installation.

---

## Step 2: Install Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Add your user to docker group
sudo usermod -aG docker $USER

# Apply group changes (or log out and back in)
newgrp docker

# Verify Docker works
docker --version
docker compose version
```

---

## Step 3: Clone the Repository

```bash
# Create directory
sudo mkdir -p /opt/aiinference
sudo chown $USER:$USER /opt/aiinference
cd /opt/aiinference

# Clone repository
git clone https://github.com/TechnosiveUK/aiinference.git .

# Verify files
ls -la
```

You should see:
- `setup.sh`
- `start.sh`
- `stop.sh`
- `verify.sh`
- `docker-compose.yaml`
- `config/`
- etc.

---

## Step 4: Run Setup Script

```bash
cd /opt/aiinference

# Run setup (this will install NVIDIA Container Toolkit and configure everything)
sudo ./setup.sh
```

**What the setup script does:**
1. ✅ Validates NVIDIA driver (`nvidia-smi`)
2. ✅ Checks GPU model (T4)
3. ✅ Verifies Ubuntu version (24.04)
4. ✅ Installs NVIDIA Container Toolkit
5. ✅ Configures Docker for GPU access
6. ✅ Adds user to docker group
7. ✅ Tests GPU access in Docker
8. ✅ Sets up directory permissions

**Expected output:**
```
=== PrivaXAI AI Inference Stack Setup ===

1. Checking NVIDIA driver...
[GPU information]
✓ NVIDIA driver detected

Detected GPU: Tesla T4

2. Checking Ubuntu version...
OS: Ubuntu 24.04.3 LTS

3. Installing NVIDIA Container Toolkit...
[Installation progress]
✓ NVIDIA Container Toolkit installed

4. Verifying Docker...
Docker version X.X.X
Docker Compose version vX.X.X
✓ Docker ready

5. Testing GPU access in Docker...
[Pulling CUDA image...]
✓ GPU access verified in Docker

6. Setting up directory permissions...
✓ Directory permissions set

=== Setup Complete ===
```

**If setup fails:**
- Check the error message
- See TROUBLESHOOTING.md for solutions
- Most common issues are already handled by the script

---

## Step 5: Start the Stack

```bash
cd /opt/aiinference

# Start all services (this will pull the model on first run)
./start.sh
```

**What this does:**
1. ✅ Starts Docker Compose services (Ollama, TensorZero, ClickHouse)
2. ✅ Waits for ClickHouse to be ready
3. ✅ Initializes ClickHouse database
4. ✅ Waits for Ollama to be ready
5. ✅ Pulls Qwen 2.5 Coder 7B model (~4.4GB, first run only)
6. ✅ Verifies model is available

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
[Download progress...]
✓ Model pulled successfully
7. Verifying model...
✓ Model verified

=== Stack Started Successfully ===
```

**First run notes:**
- Model download takes 5-15 minutes depending on internet speed
- Subsequent starts are much faster (model is cached)

---

## Step 6: Verify Everything Works

```bash
cd /opt/aiinference

# Run comprehensive verification
./verify.sh
```

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
   [Memory and GPU usage stats]

=== Verification Complete ===
```

---

## Step 7: Test the API

```bash
# Test the API endpoint
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

You should get a JSON response with the model's reply.

---

## Quick Reference Commands

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f ollama
docker compose logs -f tensorzero
docker compose logs -f clickhouse
```

### Check Status
```bash
# Service status
docker compose ps

# GPU usage
nvidia-smi

# Resource usage
docker stats
```

### Stop Stack
```bash
./stop.sh
```

### Restart Stack
```bash
./stop.sh
./start.sh
```

---

## Troubleshooting

### Setup Script Fails

1. **NVIDIA driver not found:**
   ```bash
   sudo apt update
   sudo apt install -y nvidia-driver-535
   sudo reboot
   ```

2. **Docker permission denied:**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **GPU test fails:**
   - Check `/etc/docker/daemon.json` has nvidia runtime
   - Restart Docker: `sudo systemctl restart docker`
   - Try manual test: `docker run --rm --gpus all nvidia/cuda:latest nvidia-smi`

### Services Won't Start

```bash
# Check logs
docker compose logs

# Check disk space
df -h

# Check memory
free -h

# Restart services
docker compose restart
```

### Model Won't Load

```bash
# Check Ollama logs
docker compose logs ollama

# Manually pull model
docker compose exec ollama ollama pull qwen2.5-coder:7b

# Verify model
docker compose exec ollama ollama list
```

See `TROUBLESHOOTING.md` for more detailed solutions.

---

## Security Configuration

### Firewall Setup (Recommended)

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

---

## Next Steps

1. **Configure PrivaXAI Platform**: Point it to `http://your-server-ip:8000`
2. **Set up Reverse Proxy**: Add Nginx/Traefik with authentication
3. **Enable TLS**: Use Let's Encrypt for HTTPS
4. **Monitor Usage**: Check ClickHouse for token usage data
5. **Set up Backups**: Backup `ollama/` and `clickhouse_data/` directories

---

## File Structure

```
/opt/aiinference/
├── config/
│   ├── tensorzero.toml          # Gateway configuration
│   └── clickhouse/
│       └── init.sql                 # Database initialization
├── docker-compose.yaml           # Service definitions
├── setup.sh                      # Initial setup
├── start.sh                      # Start stack
├── stop.sh                       # Stop stack
├── verify.sh                     # Verify services
├── README.md                     # Documentation
├── CLEAN_DEPLOYMENT.md           # This file
└── TROUBLESHOOTING.md            # Troubleshooting guide
```

---

## Support

For issues:
1. Check logs: `docker compose logs [service-name]`
2. Run verification: `./verify.sh`
3. Check GPU: `nvidia-smi`
4. Review configuration files
5. See `TROUBLESHOOTING.md`

---

**You're all set!** Your AI inference stack is ready to power PrivaXAI. 🚀

