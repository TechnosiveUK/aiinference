#!/bin/bash
# Quick GPU verification script
# Use this to test GPU access in Docker after hardware provider installation

set -e

echo "=== GPU Verification Test ==="
echo ""

# Test multiple CUDA image tags to find one that works
CUDA_TAGS=("latest" "12.2.0-base-ubuntu22.04" "11.8.0-base-ubuntu22.04" "12.0.0-base-ubuntu22.04")

echo "Testing CUDA image tags..."
for TAG in "${CUDA_TAGS[@]}"; do
    echo ""
    echo "Testing nvidia/cuda:$TAG..."
    if docker run --rm --gpus all nvidia/cuda:$TAG nvidia-smi &>/dev/null; then
        echo "✓ SUCCESS with nvidia/cuda:$TAG"
        echo ""
        echo "Full output:"
        docker run --rm --gpus all nvidia/cuda:$TAG nvidia-smi
        echo ""
        echo "GPU access verified! You can proceed with deployment."
        exit 0
    else
        echo "✗ Failed with nvidia/cuda:$TAG"
    fi
done

echo ""
echo "ERROR: None of the CUDA image tags worked."
echo "Troubleshooting:"
echo "1. Check NVIDIA driver: nvidia-smi"
echo "2. Check Docker daemon.json: sudo cat /etc/docker/daemon.json"
echo "3. Restart Docker: sudo systemctl restart docker"
echo "4. Check Container Toolkit: nvidia-container-toolkit --version"
exit 1

