#!/bin/bash

# AWS c6g.xlarge Build and Run Script
# Optimized for Graviton2 ARM64 with all 6 quality levels

set -e

echo "=== AWS c6g.xlarge RTMP/HLS Server Setup ==="
echo "Building for ARM64 Graviton2 with ALL 6 quality levels including 4K"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running on ARM64
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo -e "${RED}Warning: Not running on ARM64 architecture (detected: $ARCH)${NC}"
    echo "This script is optimized for AWS c6g.xlarge (ARM64/Graviton2)"
    echo "Continue anyway? (y/n)"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}Please log out and back in, then run this script again${NC}"
    exit 1
fi

# Check Docker permissions
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker permission denied. Adding user to docker group...${NC}"
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}Please run: newgrp docker${NC}"
    echo "Then run this script again"
    exit 1
fi

# Stop existing container if running
if docker ps | grep -q rtmp; then
    echo -e "${YELLOW}Stopping existing RTMP container...${NC}"
    docker stop $(docker ps --format "{{.Names}}" | grep rtmp) || true
    docker rm $(docker ps -a --format "{{.Names}}" | grep rtmp) || true
fi

# Build the ARM64-optimized image
echo -e "${BLUE}Building ARM64-optimized RTMP/HLS server...${NC}"
echo "This will take 10-15 minutes on c6g.xlarge..."

if [ -f "Dockerfile-graviton2" ]; then
    docker build -f Dockerfile-graviton2 -t rtmp-hls-graviton2 . --no-cache
else
    echo -e "${RED}Dockerfile-graviton2 not found!${NC}"
    exit 1
fi

# Create docker-compose file if it doesn't exist
if [ ! -f "docker-compose.graviton2.yml" ]; then
    echo -e "${BLUE}Creating docker-compose configuration...${NC}"
    cat > docker-compose.graviton2.yml << 'EOF'
version: '3.8'
services:
  rtmp-server:
    image: rtmp-hls-graviton2
    container_name: rtmp-graviton2-prod
    restart: unless-stopped
    ports:
      - "1935:1935"
      - "8080:8080"
    volumes:
      - hls_data:/mnt/hls
      - dash_data:/mnt/dash
      - ./logs:/var/log/nginx
    environment:
      - NGINX_WORKER_PROCESSES=4
    cpus: '4.0'
    mem_limit: 7g
    mem_reservation: 6g
    sysctls:
      - net.core.rmem_max=134217728
      - net.core.wmem_max=134217728
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  hls_data:
    driver: local
  dash_data:
    driver: local
EOF
fi

# Create logs directory
mkdir -p logs

# Start the service
echo -e "${BLUE}Starting RTMP/HLS server...${NC}"
docker-compose -f docker-compose.graviton2.yml up -d

# Wait for container to start
echo "Waiting for container to initialize..."
sleep 10

# Check if container is running
if docker ps | grep -q rtmp-graviton2-prod; then
    echo -e "${GREEN}✓ Container started successfully!${NC}"
    
    # Wait for nginx to be ready
    echo "Waiting for nginx to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/health >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Nginx is ready!${NC}"
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
    
    # Make monitoring script executable
    chmod +x monitor_c6g.sh 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}=== Deployment Successful! ===${NC}"
    echo ""
    echo -e "${BLUE}Server Endpoints:${NC}"
    echo "• RTMP Input: rtmp://$(curl -s ifconfig.me):1935/live/STREAM_NAME"
    echo "• HLS Output: http://$(curl -s ifconfig.me):8080/hls/STREAM_NAME.m3u8"
    echo "• DASH Output: http://$(curl -s ifconfig.me):8080/dash/STREAM_NAME.mpd"
    echo "• Statistics: http://$(curl -s ifconfig.me):8080/stat"
    echo "• Health Check: http://$(curl -s ifconfig.me):8080/health"
    echo ""
    echo -e "${BLUE}Quality Levels Available:${NC}"
    echo "• 360p (Low): STREAM_NAME_low.m3u8"
    echo "• 480p (Medium): STREAM_NAME_mid.m3u8"
    echo "• 720p (High): STREAM_NAME_high.m3u8"
    echo "• 1080p (HD): STREAM_NAME_hd720.m3u8"
    echo "• 1440p (QHD): STREAM_NAME_hd1080.m3u8"
    echo -e "${YELLOW}• 4K (Ultra): STREAM_NAME_hd2160.m3u8 ⚠️  CPU INTENSIVE${NC}"
    echo ""
    echo -e "${BLUE}Test Stream Command:${NC}"
    echo "ffmpeg -re -f lavfi -i testsrc2=size=1920x1080:rate=30 -f lavfi -i sine=frequency=1000:sample_rate=44100 \\"
    echo "  -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -f flv \\"
    echo "  rtmp://localhost:1935/live/test"
    echo ""
    echo -e "${BLUE}Monitoring Commands:${NC}"
    echo "• Real-time monitor: ./monitor_c6g.sh"
    echo "• Container logs: docker logs -f rtmp-graviton2-prod"
    echo "• Container stats: docker stats rtmp-graviton2-prod"
    echo ""
    echo -e "${YELLOW}⚠️  Performance Warning:${NC}"
    echo "c6g.xlarge with 6 quality levels (including 4K) will use 90-95% CPU for 1 stream"
    echo "Monitor performance closely with: ./monitor_c6g.sh"
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo "• Stop: docker-compose -f docker-compose.graviton2.yml down"
    echo "• Restart: docker-compose -f docker-compose.graviton2.yml restart"
    echo "• View logs: docker-compose -f docker-compose.graviton2.yml logs -f"
    
else
    echo -e "${RED}✗ Container failed to start${NC}"
    echo "Check logs with: docker logs rtmp-graviton2-prod"
    exit 1
fi
