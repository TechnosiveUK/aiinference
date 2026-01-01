# Hardware Provider Pre-Installed Setup

**Guide for servers where NVIDIA drivers, CUDA, and cuDNN are pre-installed by the hardware provider**

## What's Already Installed

If your hardware provider has already installed:
- ✅ NVIDIA drivers (570.158.01)
- ✅ CUDA (12.8.1)
- ✅ cuDNN (9.10.2.21)
- ✅ Docker with NVIDIA Container Toolkit configured

You can skip most of the setup steps and go straight to verification.

## Quick Verification

### 1. Verify NVIDIA Driver

```bash
nvidia-smi
```

You should see your T4 GPU information.

### 2. Verify Docker and NVIDIA Runtime

```bash
# Check Docker daemon.json
sudo cat /etc/docker/daemon.json

# Should show nvidia runtime configured
# Check Docker info
sudo docker info | grep -i runtime
```

### 3. Test GPU Access in Docker

```bash
# Use the verification script
./verify-gpu.sh

# Or test manually with a known working tag
docker run --rm --gpus all nvidia/cuda:latest nvidia-smi
```

**If the above works**, you can skip `setup.sh` and go directly to starting the stack.

## If GPU Test Fails

### Common Issues

1. **CUDA image tag doesn't exist**
   - Use `nvidia/cuda:latest` or `nvidia/cuda:12.2.0-base-ubuntu22.04`
   - Run `./verify-gpu.sh` to test multiple tags automatically

2. **Docker permission denied**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **NVIDIA Container Toolkit not fully installed**
   ```bash
   # Even if daemon.json is configured, you may need to install the toolkit
   sudo ./setup.sh
   ```

## Quick Start (Skip Setup)

If everything is verified:

```bash
cd /opt/aiinference

# Pull latest code
git pull origin main

# Start the stack directly
./start.sh
```

## Full Setup (If Needed)

If verification fails or you want to ensure everything is correct:

```bash
cd /opt/aiinference

# Run setup (will detect existing installations)
sudo ./setup.sh

# Setup will:
# - Verify existing drivers
# - Install Container Toolkit if missing
# - Configure Docker if needed
# - Test GPU access
```

## Verification Checklist

Before starting the stack, verify:

- [ ] `nvidia-smi` shows T4 GPU
- [ ] `/etc/docker/daemon.json` has nvidia runtime
- [ ] `docker run --rm --gpus all nvidia/cuda:latest nvidia-smi` works
- [ ] User is in docker group (no sudo needed for docker commands)
- [ ] Git repository is up to date

## Troubleshooting

### "Unable to find image" Error

This means the CUDA image tag doesn't exist. Use:

```bash
# Try these in order
docker run --rm --gpus all nvidia/cuda:latest nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

### "Permission denied" Error

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply immediately
newgrp docker

# Or log out and back in
```

### Container Toolkit Issues

Even if pre-installed, you may need to verify:

```bash
# Check if installed
nvidia-container-toolkit --version

# If not found, install it
sudo ./setup.sh
```

---

**Once GPU access is verified, proceed with `./start.sh` to deploy the stack.**

