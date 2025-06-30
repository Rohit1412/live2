# AWS c6g.xlarge Deployment Guide - All 6 Quality Levels

Optimized deployment for **AWS c6g.xlarge** (4 vCPU Graviton2, 8GB RAM) with **ALL 6 quality presets** including 4K.

## ⚠️ Performance Reality Check

**c6g.xlarge with 6 quality levels including 4K:**
- **1 concurrent stream**: Possible but will use 90-95% CPU
- **2+ concurrent streams**: Will cause severe performance issues
- **4K encoding**: Extremely CPU-intensive on 4 vCPUs

## Why Docker for c6g.xlarge?

✅ **AWS-optimized ARM64 base images**  
✅ **Pre-compiled ARM64 binaries**  
✅ **Graviton2-specific optimizations**  
✅ **Easier deployment and scaling**  

## Quick Deployment

### 1. Prepare AWS Instance

```bash
# Connect to your c6g.xlarge instance
ssh -i your-key.pem ubuntu@your-instance-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
newgrp docker

# Install monitoring tools
sudo apt install -y htop iotop nethogs
```

### 2. Clone and Build

```bash
# Clone repository
git clone <your-repo> rtmp-hls-server
cd rtmp-hls-server

# Build ARM64-optimized image
docker build -f Dockerfile-graviton2 -t rtmp-hls-graviton2 .
```

### 3. Create Production Docker Compose

Create `docker-compose.graviton2.yml`:

```yaml
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
    # Graviton2 optimizations
    cpus: '4.0'
    mem_limit: 7g
    mem_reservation: 6g
    # CPU affinity for better performance
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

networks:
  default:
    driver: bridge
```

### 4. Deploy with Monitoring

```bash
# Start the service
docker-compose -f docker-compose.graviton2.yml up -d

# Monitor startup (4K encoding takes time to initialize)
docker-compose -f docker-compose.graviton2.yml logs -f

# Check health
docker-compose -f docker-compose.graviton2.yml ps
```

## Performance Monitoring

### Real-time Monitoring Script

Create `monitor_graviton2.sh`:

```bash
#!/bin/bash

echo "=== c6g.xlarge RTMP/HLS Monitor ==="
echo "Timestamp: $(date)"
echo ""

# System resources
echo "=== Graviton2 System Resources ==="
echo "Load Average: $(cat /proc/loadavg)"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory: $(free -h | grep Mem | awk '{printf "Used: %s/%s (%.1f%%)", $3, $2, $3/$2 * 100.0}')"
echo "Disk: $(df -h /var/lib/docker | tail -1 | awk '{printf "Used: %s/%s (%s)", $3, $2, $5}')"
echo ""

# Container stats
echo "=== Container Performance ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
echo ""

# FFmpeg processes
echo "=== Active FFmpeg Processes ==="
docker exec rtmp-graviton2-prod ps aux | grep ffmpeg | grep -v grep | wc -l
echo "FFmpeg processes running"
echo ""

# Stream statistics
echo "=== Stream Statistics ==="
curl -s http://localhost:8080/stat 2>/dev/null | grep -E "(name|bw_in|bw_out)" | head -10
echo ""

# Network connections
echo "=== Network Connections ==="
echo "RTMP: $(netstat -an | grep :1935 | grep ESTABLISHED | wc -l) active"
echo "HLS: $(netstat -an | grep :8080 | grep ESTABLISHED | wc -l) active"
```

Make it executable:
```bash
chmod +x monitor_graviton2.sh
```

### Automated Performance Alerts

Create `performance_check.sh`:

```bash
#!/bin/bash

# CPU threshold (%)
CPU_THRESHOLD=95
# Memory threshold (%)
MEM_THRESHOLD=90

# Get current usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

# Check CPU
if [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ]; then
    echo "ALERT: CPU usage is ${CPU_USAGE}% (threshold: ${CPU_THRESHOLD}%)"
    echo "Consider reducing quality levels or concurrent streams"
fi

# Check Memory
if [ "$MEM_USAGE" -gt "$MEM_THRESHOLD" ]; then
    echo "ALERT: Memory usage is ${MEM_USAGE}% (threshold: ${MEM_THRESHOLD}%)"
    echo "Consider restarting the container"
fi

# Check FFmpeg processes
FFMPEG_COUNT=$(docker exec rtmp-graviton2-prod ps aux | grep ffmpeg | grep -v grep | wc -l)
if [ "$FFMPEG_COUNT" -gt 6 ]; then
    echo "ALERT: Too many FFmpeg processes ($FFMPEG_COUNT). Expected max 6 per stream."
fi
```

Add to crontab for monitoring:
```bash
# Check every 2 minutes
*/2 * * * * /home/ubuntu/rtmp-hls-server/performance_check.sh >> /var/log/performance.log 2>&1
```

## Optimization Strategies

### 1. Dynamic Quality Scaling

Create a script to reduce quality levels under high load:

```bash
#!/bin/bash
# fallback_quality.sh

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)

if [ "$CPU_USAGE" -gt 90 ]; then
    echo "High CPU detected ($CPU_USAGE%). Switching to 3-quality config..."
    docker exec rtmp-graviton2-prod cp /etc/nginx/nginx-3quality.conf /etc/nginx/nginx.conf
    docker exec rtmp-graviton2-prod nginx -s reload
else
    echo "CPU normal ($CPU_USAGE%). Using full 6-quality config..."
    docker exec rtmp-graviton2-prod cp /etc/nginx/nginx-6quality.conf /etc/nginx/nginx.conf
    docker exec rtmp-graviton2-prod nginx -s reload
fi
```

### 2. AWS Instance Optimization

```bash
# Optimize network performance
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 65536 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Set CPU governor to performance
echo 'performance' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### 3. Storage Optimization

```bash
# Use instance store if available, or optimize EBS
# Mount additional EBS volume for HLS/DASH storage
sudo mkfs.ext4 /dev/nvme1n1
sudo mkdir -p /mnt/streaming
sudo mount /dev/nvme1n1 /mnt/streaming
sudo chown ubuntu:ubuntu /mnt/streaming

# Update docker-compose to use optimized storage
# Add to volumes section:
# - /mnt/streaming/hls:/mnt/hls
# - /mnt/streaming/dash:/mnt/dash
```

## Testing Your Setup

### 1. Single Stream Test

```bash
# Test with a simple stream first
ffmpeg -re -f lavfi -i testsrc2=size=1920x1080:rate=30 -f lavfi -i sine=frequency=1000:sample_rate=44100 \
    -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -f flv \
    rtmp://your-instance-ip:1935/live/test

# Monitor during test
./monitor_graviton2.sh
```

### 2. Quality Level Verification

```bash
# Check all quality levels are being generated
curl http://your-instance-ip:8080/hls/test.m3u8

# Should show 6 different quality streams:
# test_low.m3u8 (360p)
# test_mid.m3u8 (480p) 
# test_high.m3u8 (720p)
# test_hd720.m3u8 (1080p)
# test_hd1080.m3u8 (1440p)
# test_hd2160.m3u8 (4K)
```

### 3. Load Testing

```bash
# CAREFUL: This will max out your CPU
# Start with ONE stream and monitor before adding more

# Test 1 stream
ffmpeg -re -i sample_video.mp4 -c copy -f flv rtmp://your-instance-ip:1935/live/stream1 &

# Monitor CPU usage
watch -n 1 'top -bn1 | grep "Cpu(s)"'

# If CPU < 80%, you can try a second stream (NOT RECOMMENDED for 4K)
```

## Scaling Recommendations

### Horizontal Scaling (Recommended)

Instead of overloading one c6g.xlarge:

1. **Use multiple c6g.xlarge instances**
2. **Load balancer for RTMP input**
3. **CDN for HLS/DASH output**

### Vertical Scaling Options

If you need more performance:

- **c6g.2xlarge** (8 vCPU, 16GB) - Can handle 2-3 concurrent 4K streams
- **c6g.4xlarge** (16 vCPU, 32GB) - Can handle 6-8 concurrent 4K streams
- **c6gn.xlarge** - Same specs but with enhanced networking

## Troubleshooting

### High CPU Usage
```bash
# Check which quality level is causing issues
docker exec rtmp-graviton2-prod ps aux | grep ffmpeg

# Temporarily disable 4K
# Edit nginx config to comment out 4K encoding line
```

### Memory Issues
```bash
# Check memory usage
docker exec rtmp-graviton2-prod free -h

# Restart container if memory leak detected
docker-compose -f docker-compose.graviton2.yml restart
```

### Stream Drops
```bash
# Check nginx error logs
docker-compose -f docker-compose.graviton2.yml logs | grep ERROR

# Check network connectivity
curl -I http://localhost:8080/health
```

## Cost Optimization

- **Spot Instances**: Use c6g.xlarge spot instances for testing (60-70% cost savings)
- **Reserved Instances**: For production, reserve instances for 1-3 years
- **Auto Scaling**: Scale down during low usage periods

---

**Reality Check**: With 4 vCPUs and 6 quality levels including 4K, you're pushing the limits. Monitor closely and be prepared to scale up or reduce quality levels based on actual performance.
