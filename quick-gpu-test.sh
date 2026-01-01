#!/bin/bash
# Quick GPU test - tests with existing images or skips pull if network is slow

echo "=== Quick GPU Test ==="
echo ""

# Check if any CUDA images exist locally
echo "Checking for existing CUDA images..."
EXISTING_IMAGES=$(docker images nvidia/cuda --format "{{.Tag}}" 2>/dev/null | head -1)

if [ -n "$EXISTING_IMAGES" ]; then
    echo "Found existing image: nvidia/cuda:$EXISTING_IMAGES"
    echo "Testing GPU access..."
    echo ""
    
    if sudo docker run --rm --gpus all nvidia/cuda:$EXISTING_IMAGES nvidia-smi; then
        echo ""
        echo "✓ GPU access verified!"
        exit 0
    else
        echo ""
        echo "✗ GPU access failed with existing image"
    fi
else
    echo "No existing CUDA images found"
fi

echo ""
echo "=== Alternative: Test with a smaller image ==="
echo "Trying to pull a smaller CUDA image (this should be faster)..."
echo ""

# Try pulling a smaller base image
if timeout 120 docker pull nvidia/cuda:12.2.0-base-ubuntu22.04 2>&1 | grep -E "(Pulling|Downloading|Extracting|Pull complete|Error)"; then
    echo ""
    echo "Testing GPU access..."
    if sudo docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi; then
        echo ""
        echo "✓ GPU access verified!"
        exit 0
    fi
else
    echo ""
    echo "✗ Could not pull image (network timeout or connection issue)"
fi

echo ""
echo "=== Manual Test ==="
echo "If network is slow, try manually:"
echo "1. Check network: ping 8.8.8.8"
echo "2. Test Docker Hub: curl -I https://hub.docker.com"
echo "3. Pull image manually: sudo docker pull nvidia/cuda:latest"
echo "4. Then test: sudo docker run --rm --gpus all nvidia/cuda:latest nvidia-smi"
echo ""
exit 1

