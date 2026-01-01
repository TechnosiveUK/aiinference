# Network Troubleshooting for Docker Image Pulls

**Solutions for slow or blocked Docker Hub access**

## Quick Network Test

Run these to diagnose:

```bash
# Test basic connectivity
ping -c 3 8.8.8.8

# Test Docker Hub access
curl -I https://hub.docker.com
curl -I https://registry-1.docker.io

# Test DNS resolution
nslookup registry-1.docker.io
```

## Solutions

### Solution 1: Use Docker Registry Mirror (China/Asia)

If you're in a region with restricted Docker Hub access:

```bash
# Edit Docker daemon.json
sudo nano /etc/docker/daemon.json

# Add registry mirrors (example for China)
{
  "runtimes": {
    "nvidia": {
      "args": [],
      "path": "nvidia-container-runtime"
    }
  },
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}

# Restart Docker
sudo systemctl restart docker

# Try pulling again
sudo docker pull nvidia/cuda:latest
```

### Solution 2: Skip GPU Test and Proceed

Since your hardware provider already installed everything, you can skip the GPU test and proceed directly:

```bash
cd /opt/aiinference
git pull origin main

# Start the stack - it will handle image pulls
sudo ./start.sh
```

The stack will pull images as needed during startup. If network is slow, it may take longer but will eventually complete.

### Solution 3: Pull Images in Background

```bash
# Pull images in background (they'll be cached)
sudo docker pull nvidia/cuda:latest &
sudo docker pull ollama/ollama:latest &
sudo docker pull clickhouse/clickhouse-server:latest &

# Check progress
docker images

# Once images are pulled, test GPU
sudo docker run --rm --gpus all nvidia/cuda:latest nvidia-smi
```

### Solution 4: Use Alternative Image Sources

If Docker Hub is completely blocked, you may need to:

1. **Use a VPN or proxy** for Docker pulls
2. **Use a local registry** if you have one
3. **Export/import images** from another machine

## Proceeding Without GPU Test

If network is the only issue and your hardware provider already configured everything:

```bash
# Verify NVIDIA driver works
nvidia-smi

# Verify Docker daemon.json has nvidia runtime
sudo cat /etc/docker/daemon.json

# If both are good, proceed with stack startup
cd /opt/aiinference
sudo ./start.sh
```

The `start.sh` script will:
- Pull images as needed (may take time with slow network)
- Test GPU access during startup
- Provide better error messages if something fails

## Expected Behavior

With slow network:
- Image pulls may take 10-30 minutes
- This is normal for large images (CUDA images are 1-2GB)
- Be patient and let it complete

## If Images Still Won't Pull

1. **Check firewall rules** - Docker Hub may be blocked
2. **Check proxy settings** - Some networks require proxy
3. **Contact your hosting provider** - They may need to whitelist Docker Hub
4. **Use alternative registry** - See Solution 1 above

---

**Recommendation**: If `nvidia-smi` works and `/etc/docker/daemon.json` has nvidia runtime configured, proceed with `./start.sh` and let it handle image pulls.

