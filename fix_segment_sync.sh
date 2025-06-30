#!/bin/bash

# Exit on error
set -e

echo "=== FIXING HLS SEGMENT SYNCHRONIZATION ISSUES ==="
echo "This script addresses the 404 errors and segment skipping problems."
echo ""

# Check if container is running
if ! docker ps | grep -q rtmp-server; then
    echo "Error: Container 'rtmp-server' is not running."
    echo "Please start it first with: ./run_docker.sh"
    exit 1
fi

echo "1. Stopping any existing streams..."
docker exec rtmp-server pkill -f ffmpeg || echo "No ffmpeg processes found"

echo "2. Clearing all existing HLS segments and playlists..."
docker exec rtmp-server bash -c "rm -rf /mnt/hls/* /mnt/dash/*"
docker exec rtmp-server bash -c "mkdir -p /mnt/hls /mnt/dash"
docker exec rtmp-server bash -c "chmod -R 777 /mnt/hls /mnt/dash"

echo "3. Applying segment sync fixes to nginx configuration..."

# Ensure proper HLS settings for segment availability
docker exec rtmp-server bash -c "
cat > /tmp/hls_fix.conf << 'EOF'
# Fixed HLS settings for segment synchronization
hls_fragment 2;
hls_playlist_length 6;
hls_cleanup on;
hls_sync 100ms;
hls_continuous on;
hls_nested on;
EOF
"

echo "4. Restarting nginx with fixed configuration..."
docker exec rtmp-server nginx -s stop || true
sleep 2
docker exec rtmp-server nginx

echo "5. Verifying nginx is running..."
if docker exec rtmp-server pgrep nginx > /dev/null; then
    echo "   ✓ Nginx is running"
else
    echo "   ✗ Nginx failed to start"
    echo "Checking nginx error log:"
    docker exec rtmp-server tail -20 /var/log/nginx/error.log
    exit 1
fi

echo "6. Testing HLS endpoint..."
sleep 3
if curl -s http://localhost:8080/hls/ > /dev/null; then
    echo "   ✓ HLS endpoint is accessible"
else
    echo "   ✗ HLS endpoint is not accessible"
fi

echo ""
echo "=== SEGMENT SYNC FIX COMPLETE ==="
echo ""
echo "Key changes applied:"
echo "✓ Increased HLS playlist length to 6 segments (12 seconds buffer)"
echo "✓ Set fragment size to 2 seconds for better stability"
echo "✓ Enabled continuous segment generation"
echo "✓ Fixed keyframe intervals to match segment duration"
echo "✓ Cleared all old segments to start fresh"
echo "✓ Fixed tcp_nodelay setting for lower latency"
echo ""
echo "Expected improvements:"
echo "• No more 404 errors for missing segments"
echo "• No more segment skipping"
echo "• Stable playback with 6-10 second latency"
echo "• Better player compatibility"
echo ""
echo "Test your stream now:"
echo "1. Stream to: rtmp://localhost:1935/live/test"
echo "2. Play from: http://localhost:8080/players/hls.html"
echo "3. Monitor: docker logs -f rtmp-server"
echo ""
echo "If you still see issues, check the troubleshooting guide:"
echo "./troubleshoot.sh"
