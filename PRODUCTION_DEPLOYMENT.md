# RTMP/HLS Server Production Deployment Guide

This guide provides step-by-step instructions for deploying the RTMP/HLS streaming server with nginx configuration to production environments.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Server Requirements](#server-requirements)
- [Deployment Options](#deployment-options)
- [Docker Deployment (Recommended)](#docker-deployment-recommended)
- [Native Installation](#native-installation)
- [Production Configuration](#production-configuration)
- [Security Considerations](#security-considerations)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements
- **CPU**: Minimum 4 cores (8+ cores recommended for 4K streaming)
- **RAM**: Minimum 8GB (16GB+ recommended)
- **Storage**: SSD with at least 100GB free space
- **Network**: High-bandwidth connection (100Mbps+ upload recommended)
- **OS**: Ubuntu 20.04 LTS, CentOS 8, or Debian 11 (recommended)

### Software Dependencies
- Docker 20.10+ and Docker Compose (for containerized deployment)
- OR nginx with RTMP module + FFmpeg (for native installation)
- SSL certificates (for HTTPS/secure streaming)
- Firewall configuration tools

## Deployment Options

### Option 1: Docker Deployment (Recommended)

Docker deployment is recommended for production as it provides:
- Consistent environment across different systems
- Easy scaling and management
- Isolated dependencies
- Simple rollback capabilities

### Option 2: Native Installation

Native installation provides:
- Better performance (no containerization overhead)
- Direct system integration
- More granular control over system resources

## Docker Deployment (Recommended)

### Step 1: Prepare the Production Server

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Step 2: Clone and Prepare the Application

```bash
# Clone the repository
git clone <your-repository-url> rtmp-hls-server
cd rtmp-hls-server

# Make scripts executable
chmod +x *.sh
```

### Step 3: Configure Production Settings

Create a production-specific nginx configuration:

```bash
# Copy the base configuration
cp conf/nginx.conf conf/nginx-production.conf
```

Edit `conf/nginx-production.conf` for production:

```nginx
# Key production changes:
worker_processes auto;
error_log /var/log/nginx/error.log warn;  # Change from 'debug' to 'warn'

# In the show application block:
hls_fragment 3;  # Increase from 1 for better performance
hls_playlist_length 30;  # Increase for better buffering

# Add rate limiting and security headers
http {
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
```

### Step 4: Create Production Docker Compose

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'
services:
  rtmp-server:
    build: .
    container_name: rtmp-hls-production
    restart: unless-stopped
    ports:
      - "1935:1935"
      - "8080:8080"
    volumes:
      - ./conf/nginx-production.conf:/etc/nginx/nginx.conf:ro
      - hls_data:/mnt/hls
      - dash_data:/mnt/dash
      - ./logs:/var/log/nginx
    environment:
      - NGINX_WORKER_PROCESSES=auto
    networks:
      - rtmp_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/stat"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  hls_data:
  dash_data:

networks:
  rtmp_network:
    driver: bridge
```

### Step 5: Build and Deploy

```bash
# Build the production image
docker-compose -f docker-compose.prod.yml build

# Start the service
docker-compose -f docker-compose.prod.yml up -d

# Verify deployment
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f
```

### Step 6: Configure Reverse Proxy (Optional but Recommended)

For SSL termination and load balancing, set up nginx as a reverse proxy:

```bash
# Install nginx on host
sudo apt install nginx

# Create reverse proxy configuration
sudo nano /etc/nginx/sites-available/rtmp-proxy
```

Add the following configuration:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /path/to/your/certificate.crt;
    ssl_certificate_key /path/to/your/private.key;

    # HLS endpoint
    location /hls {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length';
    }

    # DASH endpoint
    location /dash {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # CORS headers
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length';
    }

    # Statistics endpoint
    location /stat {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # Restrict access to stats
        allow 192.168.1.0/24;  # Your admin network
        deny all;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/rtmp-proxy /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Native Installation

### Step 1: Install Dependencies

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y build-essential libpcre3-dev libssl-dev zlib1g-dev \
    librtmp-dev libtheora-dev libvorbis-dev libvpx-dev libfreetype6-dev \
    libmp3lame-dev libx264-dev libx265-dev yasm nasm pkg-config

# Install FFmpeg
sudo apt install -y ffmpeg
```

### Step 2: Build nginx with RTMP Module

```bash
# Download nginx and RTMP module
wget https://nginx.org/download/nginx-1.20.2.tar.gz
wget https://github.com/arut/nginx-rtmp-module/archive/v1.2.2.tar.gz

# Extract
tar -zxf nginx-1.20.2.tar.gz
tar -zxf v1.2.2.tar.gz

# Build nginx
cd nginx-1.20.2
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_slice_module \
    --add-module=../nginx-rtmp-module-1.2.2

make -j$(nproc)
sudo make install
```

### Step 3: Create System Service

```bash
sudo nano /etc/systemd/system/nginx.service
```

Add the following content:

```ini
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=process
KillSignal=SIGQUIT
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### Step 4: Deploy Configuration

```bash
# Copy your nginx configuration
sudo cp conf/nginx.conf /etc/nginx/nginx.conf

# Create necessary directories
sudo mkdir -p /mnt/hls /mnt/dash
sudo chown -R nginx:nginx /mnt/hls /mnt/dash
sudo chmod -R 755 /mnt/hls /mnt/dash

# Start and enable nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

## Production Configuration

### Firewall Configuration

```bash
# UFW (Ubuntu)
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 1935/tcp    # RTMP
sudo ufw allow 8080/tcp    # HLS/DASH (if not using reverse proxy)
sudo ufw enable

# iptables (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=1935/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### Performance Tuning

Edit `/etc/sysctl.conf`:

```bash
# Network performance
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000

# Apply changes
sudo sysctl -p
```

### Log Rotation

Create `/etc/logrotate.d/nginx-rtmp`:

```bash
/var/log/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 nginx nginx
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 `cat /var/run/nginx.pid`
        fi
    endscript
}
```

## Security Considerations

### 1. Stream Authentication

Add authentication to your RTMP streams by modifying the nginx configuration:

```nginx
application live {
    live on;
    
    # Enable authentication
    on_publish http://your-auth-server.com/auth;
    on_publish_done http://your-auth-server.com/auth_done;
    
    # Restrict publishing to specific IPs
    allow publish 192.168.1.0/24;
    deny publish all;
}
```

### 2. Rate Limiting

Add rate limiting to prevent abuse:

```nginx
http {
    limit_req_zone $binary_remote_addr zone=hls:10m rate=10r/s;
    
    server {
        location /hls {
            limit_req zone=hls burst=20 nodelay;
            # ... rest of configuration
        }
    }
}
```

### 3. SSL/TLS Configuration

For production, always use HTTPS for HLS/DASH endpoints:

```nginx
server {
    listen 443 ssl http2;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
}
```

## Monitoring and Maintenance

### Health Checks

Create a health check script `health_check.sh`:

```bash
#!/bin/bash

# Check if nginx is running
if ! pgrep nginx > /dev/null; then
    echo "ERROR: nginx is not running"
    exit 1
fi

# Check if RTMP port is listening
if ! netstat -ln | grep :1935 > /dev/null; then
    echo "ERROR: RTMP port 1935 is not listening"
    exit 1
fi

# Check if HTTP port is listening
if ! netstat -ln | grep :8080 > /dev/null; then
    echo "ERROR: HTTP port 8080 is not listening"
    exit 1
fi

# Check disk space for HLS/DASH storage
DISK_USAGE=$(df /mnt | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "WARNING: Disk usage is ${DISK_USAGE}%"
fi

echo "All checks passed"
```

### Monitoring Script

Create `monitor_production.sh`:

```bash
#!/bin/bash

echo "=== RTMP/HLS Server Production Monitor ==="
echo "Timestamp: $(date)"
echo ""

# System resources
echo "=== System Resources ==="
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
echo "Disk Usage: $(df -h /mnt | tail -1 | awk '{print $5}')"
echo ""

# Network connections
echo "=== Active Connections ==="
echo "RTMP connections: $(netstat -an | grep :1935 | grep ESTABLISHED | wc -l)"
echo "HTTP connections: $(netstat -an | grep :8080 | grep ESTABLISHED | wc -l)"
echo ""

# Stream statistics
echo "=== Stream Statistics ==="
curl -s http://localhost:8080/stat | grep -E "(name|bw_in|bw_out|bytes_in|bytes_out)" | head -20
echo ""

# Log errors
echo "=== Recent Errors ==="
tail -10 /var/log/nginx/error.log | grep ERROR
```

### Automated Cleanup

Create a cleanup script for old HLS/DASH segments:

```bash
#!/bin/bash
# cleanup_segments.sh

HLS_DIR="/mnt/hls"
DASH_DIR="/mnt/dash"
RETENTION_HOURS=24

# Clean old HLS segments
find $HLS_DIR -name "*.ts" -mtime +$RETENTION_HOURS -delete
find $HLS_DIR -name "*.m3u8" -mtime +$RETENTION_HOURS -delete

# Clean old DASH segments
find $DASH_DIR -name "*.m4s" -mtime +$RETENTION_HOURS -delete
find $DASH_DIR -name "*.mpd" -mtime +$RETENTION_HOURS -delete

echo "Cleanup completed at $(date)"
```

Add to crontab:
```bash
# Run cleanup every hour
0 * * * * /path/to/cleanup_segments.sh >> /var/log/cleanup.log 2>&1
```

## Troubleshooting

### Common Issues

1. **High CPU Usage**
   - Reduce FFmpeg encoding quality settings
   - Limit concurrent streams
   - Use hardware encoding if available

2. **Memory Leaks**
   - Monitor nginx worker processes
   - Restart nginx periodically if needed
   - Check for zombie FFmpeg processes

3. **Network Issues**
   - Verify firewall settings
   - Check bandwidth limitations
   - Monitor network interface statistics

4. **Storage Issues**
   - Implement automatic cleanup
   - Monitor disk space
   - Use separate storage for segments

### Log Analysis

```bash
# Monitor real-time logs
tail -f /var/log/nginx/error.log

# Check for specific errors
grep "ERROR" /var/log/nginx/error.log | tail -20

# Monitor access patterns
tail -f /var/log/nginx/access.log | grep "/hls/"
```

### Performance Testing

```bash
# Test RTMP publishing
ffmpeg -re -i test_video.mp4 -c copy -f flv rtmp://your-server:1935/live/test

# Test HLS playback
curl -I http://your-server:8080/hls/test.m3u8

# Load testing with multiple streams
for i in {1..10}; do
    ffmpeg -re -i test_video.mp4 -c copy -f flv rtmp://your-server:1935/live/test$i &
done
```

## Backup and Recovery

### Configuration Backup

```bash
# Create backup script
#!/bin/bash
BACKUP_DIR="/backup/rtmp-server"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configurations
tar -czf $BACKUP_DIR/config_$DATE.tar.gz /etc/nginx/nginx.conf conf/

# Backup any custom scripts
tar -czf $BACKUP_DIR/scripts_$DATE.tar.gz *.sh

echo "Backup completed: $BACKUP_DIR"
```

### Disaster Recovery

1. **Server Failure**: Use configuration backups to rebuild on new server
2. **Data Loss**: Implement real-time replication for critical streams
3. **Network Issues**: Set up multiple streaming endpoints

## Scaling Considerations

### Horizontal Scaling

For high-traffic deployments:

1. **Load Balancer**: Use nginx or HAProxy to distribute load
2. **Multiple Instances**: Run multiple RTMP servers behind load balancer
3. **CDN Integration**: Use CDN for HLS/DASH delivery
4. **Database**: Store stream metadata in shared database

### Vertical Scaling

1. **CPU**: More cores for concurrent encoding
2. **Memory**: More RAM for buffering and caching
3. **Storage**: Faster SSD for segment storage
4. **Network**: Higher bandwidth for more concurrent streams

---

## Support and Maintenance

- Monitor server resources regularly
- Keep nginx and FFmpeg updated
- Review logs for errors and performance issues
- Test streaming functionality after any changes
- Maintain backup and recovery procedures

For additional support, refer to the project documentation or create an issue in the repository.
