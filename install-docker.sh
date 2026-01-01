#!/bin/bash
# Install Docker and Docker Compose
# Run this if Docker is not installed

set -e

echo "=== Installing Docker and Docker Compose ==="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo "✓ Docker is already installed"
    docker --version
    exit 0
fi

echo "Installing Docker..."
echo ""

# Install Docker using official script
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh

# Install Docker Compose plugin
echo ""
echo "Installing Docker Compose plugin..."
apt-get update
apt-get install -y docker-compose-plugin

# Add current user to docker group
if [ -n "$SUDO_USER" ]; then
    echo ""
    echo "Adding $SUDO_USER to docker group..."
    usermod -aG docker $SUDO_USER
    echo "✓ User added to docker group"
    echo "  NOTE: You may need to log out and back in, or run: newgrp docker"
fi

# Start and enable Docker
echo ""
echo "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Wait for Docker to be ready
sleep 3

# Verify installation
echo ""
echo "Verifying installation..."
docker --version
docker compose version

echo ""
echo "✓ Docker and Docker Compose installed successfully"
echo ""
echo "Next steps:"
echo "1. If you're not root, log out and back in, or run: newgrp docker"
echo "2. Run: cd /opt/aiinference && sudo ./setup.sh"
echo ""

