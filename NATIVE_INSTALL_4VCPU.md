# Native Installation Guide for 4 vCPU System

This guide is optimized for your 4 vCPU system to maximize performance for RTMP/HLS streaming.

## Why Native Installation for 4 vCPUs?

- **No Docker overhead**: Save 5-15% CPU performance
- **Direct hardware access**: Better for video encoding
- **Optimized resource allocation**: Pin processes to specific CPU cores
- **Lower memory footprint**: No container abstraction

## Quick Installation Steps

### 1. System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y build-essential libpcre3-dev libssl-dev zlib1g-dev \
    librtmp-dev libtheora-dev libvorbis-dev libvpx-dev libfreetype6-dev \
    libmp3lame-dev libx264-dev libx265-dev yasm nasm pkg-config wget git

# Install FFmpeg (optimized version)
sudo apt install -y ffmpeg

# Verify FFmpeg has x264 support
ffmpeg -encoders | grep x264
```

### 2. Build Nginx with RTMP Module

```bash
# Create build directory
mkdir -p ~/nginx-build && cd ~/nginx-build

# Download sources
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
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-threads \
    --add-module=../nginx-rtmp-module-1.2.2

# Compile (use all 4 cores)
make -j4

# Install
sudo make install
```

### 3. System Configuration

```bash
# Create nginx user
sudo useradd --system --home /var/cache/nginx --shell /sbin/nologin --comment "nginx user" --user-group nginx

# Create directories
sudo mkdir -p /var/cache/nginx /var/log/nginx /mnt/hls /mnt/dash
sudo chown -R nginx:nginx /var/cache/nginx /var/log/nginx /mnt/hls /mnt/dash
sudo chmod -R 755 /mnt/hls /mnt/dash

# Copy optimized configuration
sudo cp conf/nginx-4vcpu-optimized.conf /etc/nginx/nginx.conf

# Copy stat.xsl for statistics
sudo mkdir -p /usr/local/nginx/html
sudo cp ~/nginx-build/nginx-rtmp-module-1.2.2/stat.xsl /usr/local/nginx/html/
```

### 4. Create Systemd Service

```bash
sudo tee /etc/systemd/system/nginx.service > /dev/null <<EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=process
KillSignal=SIGQUIT
TimeoutStopSec=5
PrivateTmp=true
User=nginx
Group=nginx

# CPU and memory optimizations for 4 vCPU system
CPUAffinity=0-3
MemoryHigh=2G
MemoryMax=3G

[Install]
WantedBy=multi-user.target
EOF
```

### 5. System Optimizations for 4 vCPUs

```bash
# Optimize kernel parameters
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Network optimizations for streaming
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 65536 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 2500

# CPU scheduling optimizations
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 0
EOF

# Apply changes
sudo sysctl -p
```

### 6. CPU Governor and Frequency Scaling

```bash
# Set CPU governor to performance mode for consistent encoding performance
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils

# Or manually set for immediate effect
sudo cpufreq-set -g performance

# Verify
cpufreq-info
```

### 7. Start and Test

```bash
# Enable and start nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Check status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Check if ports are listening
sudo netstat -tlnp | grep -E ':(1935|8080)'
```

## Performance Monitoring

### Real-time CPU monitoring during streaming:

```bash
# Monitor CPU usage per core
watch -n 1 'cat /proc/loadavg && echo "CPU per core:" && mpstat -P ALL 1 1'

# Monitor nginx processes
watch -n 2 'ps aux | grep -E "(nginx|ffmpeg)" | grep -v grep'

# Monitor memory usage
watch -n 2 'free -h && echo "Nginx memory:" && ps -o pid,ppid,cmd,%mem,%cpu --sort=-%mem | grep nginx'
```

### Stream testing:

```bash
# Test with a single stream first
ffmpeg -re -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=1000:sample_rate=44100 \
    -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -f flv \
    rtmp://localhost:1935/live/test

# Check HLS output
curl -I http://localhost:8080/hls/test.m3u8

# View statistics
curl http://localhost:8080/stat
```

## Key Optimizations Made

### 1. Reduced Quality Variants
- **Original**: 6 quality levels (360p, 480p, 720p, 1080p, 4K, source)
- **Optimized**: 3 quality levels (360p, 720p, 1080p)
- **CPU Savings**: 50% reduction in FFmpeg processes

### 2. FFmpeg Settings Optimized
- **Preset**: Changed from `superfast` to `ultrafast`
- **CRF**: Adjusted for better speed/quality balance
- **GOP**: Set to 30 frames for better encoding efficiency

### 3. Nginx Worker Optimization
- **Workers**: Set to 4 (matching vCPU count)
- **CPU Affinity**: Pin workers to specific cores
- **Memory**: Reduced buffer sizes

### 4. HLS/DASH Settings
- **Fragment Size**: 2 seconds (balance of latency/performance)
- **Playlist Length**: Reduced to 10 segments
- **Auto Cleanup**: Enabled to prevent disk filling

## Expected Performance

With these optimizations on a 4 vCPU system:
- **1 concurrent stream**: Should work smoothly
- **2 concurrent streams**: Possible but will use ~80-90% CPU
- **3+ concurrent streams**: Not recommended, will cause quality issues

## Troubleshooting

### High CPU Usage
```bash
# Check which processes are using CPU
top -p $(pgrep -d',' -f 'nginx|ffmpeg')

# If CPU is maxed, consider:
# 1. Reduce to 2 quality variants only
# 2. Lower bitrates
# 3. Use faster encoding presets
```

### Memory Issues
```bash
# Monitor memory usage
watch -n 1 'free -h && ps aux --sort=-%mem | head -10'

# If memory is high:
# 1. Reduce HLS playlist length
# 2. Enable more aggressive cleanup
# 3. Reduce worker connections
```

This setup will give you maximum performance from your 4 vCPU system!
