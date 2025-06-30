#!/bin/bash

# Exit on error
set -e

echo "=== RTMP/HLS Server Troubleshooting Script ==="
echo "This script will help diagnose and fix common issues."
echo ""

# Check Docker installation
echo "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
else
    echo "Docker is installed."
    docker --version
fi

# Check Docker permissions
echo ""
echo "Checking Docker permissions..."
if ! docker info &> /dev/null; then
    echo "You don't have permission to use Docker."
    echo "Would you like to add your user to the docker group? (y/n)"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "Adding user to docker group..."
        sudo usermod -aG docker $USER
        echo "You need to log out and log back in for this to take effect."
        echo "Alternatively, you can run: newgrp docker"
    else
        echo "You can run the scripts with sudo instead."
    fi
else
    echo "Docker permissions are correct."
fi

# Check disk space
echo ""
echo "Checking disk space..."
df -h .
echo ""
echo "At least 5GB of free space is recommended for building the Docker image."

# Check if image exists
echo ""
echo "Checking if Docker image exists..."
if docker images | grep -q rtmp-hls-server; then
    echo "Docker image 'rtmp-hls-server' exists."
    docker images rtmp-hls-server
else
    echo "Docker image 'rtmp-hls-server' does not exist."
    echo "You need to build it first with: ./build_docker.sh"
fi

# Check if container exists
echo ""
echo "Checking if Docker container exists..."
if docker ps -a | grep -q rtmp-server; then
    echo "Docker container 'rtmp-server' exists."
    docker ps -a | grep rtmp-server
    
    # Check if it's running
    if docker ps | grep -q rtmp-server; then
        echo "Container is running."
        echo "To check logs: docker logs rtmp-server"
    else
        echo "Container exists but is not running."
        echo "To start it: docker start rtmp-server"
        echo "To check logs: docker logs rtmp-server"
    fi
else
    echo "Docker container 'rtmp-server' does not exist."
    echo "You need to run it first with: ./run_docker.sh"
fi

# Check network ports
echo ""
echo "Checking if required ports are available..."
if command -v netstat &> /dev/null; then
    echo "Port 1935 (RTMP):"
    netstat -tuln | grep 1935 || echo "Port 1935 is available."
    echo "Port 8080 (HTTP):"
    netstat -tuln | grep 8080 || echo "Port 8080 is available."
else
    echo "netstat command not found. Cannot check port availability."
    echo "Make sure ports 1935 and 8080 are not in use by other applications."
fi

echo ""
echo "Troubleshooting complete."
echo ""
echo "Common issues and solutions:"
echo "1. Build fails with compiler errors:"
echo "   - Try building with: docker build --progress=plain -t rtmp-hls-server ."
echo "   - Check for specific error messages and fix them in the Dockerfile."
echo ""
echo "2. Container starts but streaming doesn't work:"
echo "   - Check if ports are correctly mapped: docker port rtmp-server"
echo "   - Check if firewall is blocking the ports: sudo ufw status"
echo "   - Check container logs: docker logs rtmp-server"
echo ""
echo "3. High latency in streaming:"
echo "   - Run the optimize_latency.sh script: ./optimize_latency.sh"
echo "   - Check network conditions between server and clients."
echo ""
echo "4. Container crashes or restarts:"
echo "   - Check logs: docker logs rtmp-server"
echo "   - Check system resources: docker stats rtmp-server"
echo "   - Increase container resources: edit run_docker.sh to add more CPU/memory."