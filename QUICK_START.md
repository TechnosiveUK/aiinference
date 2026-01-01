# Quick Start Checklist

**For fresh Ubuntu Server 24.04 LTS with NVIDIA T4 GPU**

## Pre-Flight Checklist

- [ ] Ubuntu Server 24.04 LTS installed
- [ ] NVIDIA T4 GPU installed
- [ ] Internet connection available
- [ ] At least 50GB free disk space
- [ ] Root/sudo access

---

## Installation Steps (Copy-Paste Ready)

### 1. Install NVIDIA Drivers (if needed)
```bash
sudo apt update
sudo apt install -y nvidia-driver-535
sudo reboot
# After reboot, verify: nvidia-smi
```

### 2. Install Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo apt install -y docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

### 3. Clone Repository
```bash
sudo mkdir -p /opt/aiinference
sudo chown $USER:$USER /opt/aiinference
cd /opt/aiinference
git clone https://github.com/TechnosiveUK/aiinference.git .
```

### 4. Run Setup
```bash
cd /opt/aiinference
sudo ./setup.sh
```

### 5. Start Stack
```bash
cd /opt/aiinference
./start.sh
```

### 6. Verify
```bash
cd /opt/aiinference
./verify.sh
```

### 7. Test API
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-tenant-id: test-tenant" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'
```

---

## That's It! 🎉

Your AI inference stack is now running.

**Services:**
- Ollama: Internal (port 11434)
- TensorZero Gateway: http://localhost:8000
- ClickHouse: Internal (port 8123)

**Next:** Point your PrivaXAI platform to `http://your-server-ip:8000`

---

## Common Commands

```bash
# View logs
docker compose logs -f

# Check status
docker compose ps

# Stop stack
./stop.sh

# Restart stack
./stop.sh && ./start.sh

# Check GPU
nvidia-smi
```

---

**For detailed instructions, see `CLEAN_DEPLOYMENT.md`**  
**For troubleshooting, see `TROUBLESHOOTING.md`**

