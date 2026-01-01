#!/bin/bash
# PrivaXAI AI Stack - Initial Setup Script
# Purpose: Validates NVIDIA drivers and installs NVIDIA Container Toolkit
# Run this once before starting the stack

set -e

echo "=== PrivaXAI AI Inference Stack Setup ==="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# 1. Validate NVIDIA driver compatibility
echo "1. Checking NVIDIA driver..."
if ! command -v nvidia-smi &> /dev/null; then
    echo "ERROR: nvidia-smi not found. Please install NVIDIA drivers first."
    echo "For Ubuntu 24.04:"
    echo "  sudo apt update"
    echo "  sudo apt install -y nvidia-driver-535 (or latest compatible version)"
    echo "  sudo reboot"
    exit 1
fi

nvidia-smi
echo "✓ NVIDIA driver detected"
echo ""

# 2. Check GPU model
GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
echo "Detected GPU: $GPU_MODEL"
if [[ ! "$GPU_MODEL" =~ "T4" ]]; then
    echo "WARNING: Expected NVIDIA T4, but detected $GPU_MODEL"
    echo "Stack is configured for T4 (16GB VRAM). Adjust model sizes if needed."
fi
echo ""

# 3. Check Ubuntu version
echo "2. Checking Ubuntu version..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "OS: $PRETTY_NAME"
    if [[ ! "$VERSION_ID" =~ "24.04" ]]; then
        echo "WARNING: Expected Ubuntu 24.04, but detected $VERSION_ID"
    fi
else
    echo "WARNING: Could not detect OS version"
fi
echo ""

# 4. Install NVIDIA Container Toolkit
echo "3. Installing NVIDIA Container Toolkit..."
if command -v nvidia-container-toolkit &> /dev/null; then
    echo "✓ NVIDIA Container Toolkit already installed"
    nvidia-container-toolkit --version
elif [ -f /etc/docker/daemon.json ] && grep -q "nvidia-container-runtime" /etc/docker/daemon.json; then
    echo "✓ NVIDIA Container Toolkit appears to be configured (found in daemon.json)"
    echo "   Verifying installation..."
    if ! command -v nvidia-container-toolkit &> /dev/null; then
        echo "   WARNING: daemon.json configured but nvidia-container-toolkit command not found"
        echo "   Installing NVIDIA Container Toolkit..."
    else
        echo "   ✓ Installation verified"
    fi
else
    echo "Installing NVIDIA Container Toolkit..."
    
    # Add NVIDIA GPG key
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    # Add repository (using stable/deb for Ubuntu/Debian)
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    # Install
    apt-get update
    apt-get install -y nvidia-container-toolkit
    
    # Configure Docker
    nvidia-ctk runtime configure --runtime=docker
    
    # Restart Docker to apply changes
    systemctl restart docker
    
    # Wait for Docker to be ready after restart
    echo "   Waiting for Docker to be ready..."
    sleep 5
    timeout=30
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if docker info &> /dev/null; then
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    echo "✓ NVIDIA Container Toolkit installed"
fi
echo ""

# 5. Verify Docker
echo "4. Verifying Docker..."
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found. Please install Docker first."
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    exit 1
fi

docker --version
docker compose version

# Add current user to docker group if not already added
if ! groups | grep -q docker; then
    echo "   Adding $SUDO_USER to docker group..."
    usermod -aG docker $SUDO_USER
    echo "   NOTE: You may need to log out and back in for docker group changes to take effect"
    echo "   Or run: newgrp docker"
fi

echo "✓ Docker ready"
echo ""

# 6. Test GPU access in Docker
echo "5. Testing GPU access in Docker..."
# Use a reliable CUDA image tag
# Try multiple tags in order of preference
CUDA_TAGS=("12.2.0-base-ubuntu22.04" "latest" "11.8.0-base-ubuntu22.04")
TEST_EXIT=1
TEST_OUTPUT=""

for TAG in "${CUDA_TAGS[@]}"; do
    echo "   Testing with nvidia/cuda:$TAG..."
    TEST_OUTPUT=$(docker run --rm --gpus all nvidia/cuda:$TAG nvidia-smi 2>&1)
    TEST_EXIT=$?
    if [ $TEST_EXIT -eq 0 ]; then
        echo "   ✓ Success with nvidia/cuda:$TAG"
        break
    fi
done

if [ $TEST_EXIT -eq 0 ]; then
    echo "✓ GPU access verified in Docker"
else
    echo "ERROR: GPU not accessible in Docker"
    echo "Error output:"
    echo "$TEST_OUTPUT" | head -20
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Verify Docker daemon.json has nvidia runtime:"
    echo "   sudo cat /etc/docker/daemon.json"
    echo "2. Restart Docker: sudo systemctl restart docker"
    echo "3. Verify Container Toolkit: nvidia-container-toolkit --version"
    echo "4. Try manual test: docker run --rm --gpus all nvidia/cuda:latest nvidia-smi"
    echo "   Or try: docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi"
    echo "5. If permission denied, add user to docker group: sudo usermod -aG docker $USER"
    echo "   Then log out and back in, or run: newgrp docker"
    exit 1
fi
echo ""

# 7. Create and set permissions for directories
echo "6. Setting up directory structure..."
# Create directories if they don't exist
mkdir -p ollama clickhouse_data logs config/clickhouse
# Set ownership
chown -R $SUDO_USER:$SUDO_USER ollama clickhouse_data logs config 2>/dev/null || true
# Set permissions
chmod -R 755 ollama clickhouse_data logs config
echo "✓ Directory structure created and permissions set"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Run ./start.sh to start the stack"
echo "2. Run ./verify.sh to verify everything is working"
echo ""

