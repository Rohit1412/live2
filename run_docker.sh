#!/bin/bash

# Exit on error
set -e

echo "=== RTMP/HLS Server Docker Run Script ==="
echo "This script will run the RTMP/HLS server Docker container."
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

# Check if image exists
if ! docker images | grep -q rtmp-hls-server; then
    echo "Error: Docker image 'rtmp-hls-server' not found."
    echo "Please build the image first with: ./build_docker.sh"
    exit 1
fi

# Check if container already exists
if docker ps -a | grep -q rtmp-server; then
    echo "Container 'rtmp-server' already exists."
    
    # Check if it's running
    if docker ps | grep -q rtmp-server; then
        echo "Container is already running."
        echo "To restart it: docker restart rtmp-server"
        echo "To stop it: docker stop rtmp-server"
        echo "To remove it: docker rm -f rtmp-server"
        echo ""
        echo "Current container status:"
        docker ps | grep rtmp-server
        exit 0
    else
        echo "Container exists but is not running."
        echo "Would you like to remove it and create a new one? (y/n)"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "Removing existing container..."
            docker rm rtmp-server
        else
            echo "To start the existing container: docker start rtmp-server"
            exit 0
        fi
    fi
fi

echo "Starting RTMP/HLS server container..."

# Run the Docker container with performance optimizations
docker run -d \
  -p 1935:1935 \
  -p 8080:8080 \
  --name rtmp-server \
  --restart unless-stopped \
  --memory=2g \
  --cpus=2 \
  --shm-size=512m \
  rtmp-hls-server

# Create necessary directories in the container with proper permissions
echo "Creating necessary directories in the container with proper permissions..."
docker exec rtmp-server mkdir -p /mnt/hls /mnt/dash
docker exec rtmp-server chmod -R 777 /mnt/hls /mnt/dash

# Check if container started successfully
if docker ps | grep -q rtmp-server; then
    echo "Container started successfully!"
    echo ""
    echo "Server is now running with the following endpoints:"
    echo "- RTMP: rtmp://localhost:1935/live"
    echo "- HLS: http://localhost:8080/hls"
    echo "- Status page: http://localhost:8080/stat"
    echo ""
    echo "To stream to this server using FFmpeg:"
    echo "ffmpeg -i <input> -c:v libx264 -preset superfast -tune zerolatency -c:a aac -f flv rtmp://localhost:1935/live/stream"
    echo ""
    echo "To view logs: docker logs -f rtmp-server"
    echo "To monitor: ./monitor.sh"
    echo "To optimize for low latency: ./optimize_latency.sh"
else
    echo "Error: Container failed to start."
    echo "Check logs with: docker logs rtmp-server"
fi