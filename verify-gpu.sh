#!/bin/bash
# Quick GPU verification script
# Use this to test GPU access in Docker after hardware provider installation

# Don't exit on error, we want to test all tags
set +e

echo "=== GPU Verification Test ==="
echo ""

# Test multiple CUDA image tags to find one that works
CUDA_TAGS=("latest" "12.2.0-base-ubuntu22.04" "11.8.0-base-ubuntu22.04" "12.0.0-base-ubuntu22.04")

echo "Testing CUDA image tags..."
for TAG in "${CUDA_TAGS[@]}"; do
    echo ""
    echo "Testing nvidia/cuda:$TAG..."
    
    # Check if image already exists locally
    if docker images nvidia/cuda:$TAG --format "{{.Repository}}:{{.Tag}}" | grep -q "nvidia/cuda:$TAG"; then
        echo "  Image already exists locally, skipping pull..."
    else
        echo "  Pulling image (this may take 2-5 minutes, please wait)..."
        echo "  (If this hangs, check your network connection)"
        
        # Pull with timeout (5 minutes)
        if timeout 300 docker pull nvidia/cuda:$TAG 2>&1 | tee /tmp/docker-pull.log; then
            echo "  ✓ Image pulled successfully"
        else
            PULL_EXIT=$?
            if [ $PULL_EXIT -eq 124 ]; then
                echo "  ✗ Pull timed out after 5 minutes"
                echo "  Check network connection or try again later"
            else
                echo "  ✗ Failed to pull image: nvidia/cuda:$TAG"
                echo "  Error:"
                tail -5 /tmp/docker-pull.log 2>/dev/null || echo "  (Check network connection)"
            fi
            continue
        fi
    fi
    
    echo "  Image pulled successfully, testing GPU access..."
    
    # Test GPU access and capture both stdout and stderr
    TEST_OUTPUT=$(docker run --rm --gpus all nvidia/cuda:$TAG nvidia-smi 2>&1)
    TEST_EXIT=$?
    
    if [ $TEST_EXIT -eq 0 ]; then
        echo "  ✓ SUCCESS with nvidia/cuda:$TAG"
        echo ""
        echo "Full GPU output:"
        echo "$TEST_OUTPUT"
        echo ""
        echo "GPU access verified! You can proceed with deployment."
        exit 0
    else
        echo "  ✗ Failed with nvidia/cuda:$TAG"
        echo "  Error output:"
        echo "$TEST_OUTPUT" | head -10
        echo ""
    fi
done

echo ""
echo "ERROR: None of the CUDA image tags worked."
echo ""
echo "=== Diagnostic Information ==="
echo ""

# Check NVIDIA driver
echo "1. Checking NVIDIA driver..."
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    echo "   ✓ nvidia-smi works"
else
    echo "   ✗ nvidia-smi not found"
fi
echo ""

# Check Docker daemon.json
echo "2. Checking Docker daemon.json..."
if [ -f /etc/docker/daemon.json ]; then
    echo "   Contents:"
    sudo cat /etc/docker/daemon.json | sed 's/^/   /'
    if grep -q "nvidia" /etc/docker/daemon.json; then
        echo "   ✓ NVIDIA runtime configured"
    else
        echo "   ✗ NVIDIA runtime NOT found in daemon.json"
    fi
else
    echo "   ✗ /etc/docker/daemon.json not found"
fi
echo ""

# Check Container Toolkit
echo "3. Checking NVIDIA Container Toolkit..."
if command -v nvidia-container-toolkit &> /dev/null; then
    nvidia-container-toolkit --version
    echo "   ✓ Container Toolkit installed"
else
    echo "   ✗ Container Toolkit not found"
    echo "   Run: sudo ./setup.sh"
fi
echo ""

# Check Docker info
echo "4. Checking Docker runtime configuration..."
DOCKER_RUNTIME=$(sudo docker info 2>/dev/null | grep -i runtime || echo "Could not check")
echo "   $DOCKER_RUNTIME"
echo ""

# Check if Docker can see GPU
echo "5. Testing basic Docker GPU access..."
if sudo docker run --rm --gpus all nvidia/cuda:latest nvidia-smi &>/dev/null; then
    echo "   ✓ Docker can access GPU (with sudo)"
else
    echo "   ✗ Docker cannot access GPU"
    echo "   Try: sudo docker run --rm --gpus all nvidia/cuda:latest nvidia-smi"
fi
echo ""

echo "=== Troubleshooting Steps ==="
echo "1. If nvidia-smi works but Docker doesn't:"
echo "   sudo systemctl restart docker"
echo ""
echo "2. If Container Toolkit is missing:"
echo "   sudo ./setup.sh"
echo ""
echo "3. If daemon.json is missing nvidia runtime:"
echo "   sudo nvidia-ctk runtime configure --runtime=docker"
echo "   sudo systemctl restart docker"
echo ""
echo "4. Test with sudo:"
echo "   sudo docker run --rm --gpus all nvidia/cuda:latest nvidia-smi"
echo ""
exit 1

