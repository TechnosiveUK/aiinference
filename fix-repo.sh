#!/bin/bash
# Quick fix script to remove broken NVIDIA Container Toolkit repository
# Run this on the server if setup.sh failed

set -e

echo "=== Fixing NVIDIA Container Toolkit Repository ==="
echo ""

# Remove the broken repository file
if [ -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
    echo "Removing broken repository file..."
    sudo rm /etc/apt/sources.list.d/nvidia-container-toolkit.list
    echo "✓ Broken repository file removed"
else
    echo "No broken repository file found"
fi

echo ""
echo "You can now re-run: sudo ./setup.sh"
echo ""

