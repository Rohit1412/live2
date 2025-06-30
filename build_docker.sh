#!/bin/bash

# Exit on error
set -e

echo "=== RTMP/HLS Server Docker Build Script ==="
echo "This script will build the RTMP/HLS server Docker image."
echo "Building may take several minutes depending on your system."
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if user has Docker permissions
if ! docker info &> /dev/null; then
    echo "You may need to run this script with sudo or add your user to the docker group."
    echo "Try: sudo $0"
    echo "Or:  sudo usermod -aG docker $USER && newgrp docker"
    exit 1
fi

echo "Starting Docker build process..."
echo "This will build a Docker image with:"
echo "- Nginx 1.17.5 (compiled from source)"
echo "- Nginx-rtmp-module 1.2.1 (compiled from source)"
echo "- FFmpeg 4.2.1 (compiled from source)"
echo ""
echo "Building image (this may take a while)..."

# Build the Docker image with detailed output
if docker build -t rtmp-hls-server .; then
    echo ""
    echo "Docker image built successfully!"
    echo "Image details:"
    docker images rtmp-hls-server
    echo ""
    echo "You can now run the container with:"
    echo "./run_docker.sh"
    echo ""
    echo "Or manually with:"
    echo "docker run -d -p 1935:1935 -p 8080:8080 --name rtmp-server rtmp-hls-server"
else
    echo ""
    echo "Build failed. Please check the error messages above."
    echo "Common issues:"
    echo "1. Insufficient disk space"
    echo "2. Network connectivity issues"
    echo "3. Compiler errors in the source code"
    echo ""
    echo "For more detailed debugging, try building with:"
    echo "docker build --progress=plain -t rtmp-hls-server ."
    exit 1
fi