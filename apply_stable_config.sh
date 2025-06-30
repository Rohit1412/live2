#!/bin/bash

# Exit on error
set -e

echo "=== APPLYING STABLE HLS CONFIGURATION ==="
echo "This script applies the final stable configuration to fix segment sync issues."
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires sudo privileges to update Docker container configuration."
    echo "Please run: sudo $0"
    exit 1
fi

# Check if container is running
if ! docker ps | grep -q rtmp-server; then
    echo "❌ Container 'rtmp-server' is not running"
    echo "   Solution: Run ./run_docker.sh to start the container"
    exit 1
else
    echo "✅ Container 'rtmp-server' is running"
fi

echo ""
echo "=== APPLYING CONFIGURATION FIXES ==="

# 1. Copy the updated nginx configuration
echo "1. Copying updated nginx configuration..."
docker cp conf/nginx.conf rtmp-server:/etc/nginx/nginx.conf

# 2. Test the configuration
echo "2. Testing nginx configuration..."
if docker exec rtmp-server nginx -t; then
    echo "   ✅ Configuration is valid"
else
    echo "   ❌ Configuration has errors"
    exit 1
fi

# 3. Stop any existing FFmpeg processes
echo "3. Stopping existing streams..."
docker exec rtmp-server pkill -f ffmpeg || echo "   No FFmpeg processes to stop"

# 4. Clear old segments
echo "4. Clearing old HLS segments..."
docker exec rtmp-server bash -c "rm -rf /mnt/hls/* /mnt/dash/*"
docker exec rtmp-server bash -c "mkdir -p /mnt/hls /mnt/dash"
docker exec rtmp-server bash -c "chmod -R 777 /mnt/hls /mnt/dash"

# 5. Reload nginx with new configuration
echo "5. Reloading nginx with new configuration..."
docker exec rtmp-server nginx -s reload

# 6. Wait for nginx to stabilize
echo "6. Waiting for nginx to stabilize..."
sleep 3

# 7. Verify nginx is running
if docker exec rtmp-server pgrep nginx > /dev/null; then
    echo "   ✅ Nginx is running with new configuration"
else
    echo "   ❌ Nginx failed to start"
    echo "Checking error log:"
    docker exec rtmp-server tail -10 /var/log/nginx/error.log
    exit 1
fi

echo ""
echo "=== CONFIGURATION APPLIED SUCCESSFULLY ==="
echo ""
echo "Key improvements:"
echo "✅ HLS fragment size: 3 seconds (more stable)"
echo "✅ Playlist length: 10 segments (30-second buffer)"
echo "✅ GOP size: 90 frames (3 seconds, matches fragment size)"
echo "✅ Forced keyframes every 3 seconds"
echo "✅ Enabled HLS caching for better performance"
echo ""
echo "Expected results:"
echo "• No more 404 segment errors"
echo "• No more 'skipping segments ahead' messages"
echo "• Stable playback with 10-15 second latency"
echo "• Better player compatibility"
echo ""
echo "Test your stream now:"
echo "1. Stream to: rtmp://localhost:1935/live/test"
echo "2. Play with: ffplay -i http://localhost:8080/hls/stream.m3u8"
echo "3. Or use browser: http://localhost:8080/players/hls.html"
echo ""
echo "Monitor with: docker logs -f rtmp-server"
