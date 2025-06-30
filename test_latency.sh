#!/bin/bash

# Exit on error
set -e

echo "=== RTMP/HLS Latency Test Script ==="
echo "This script helps measure the end-to-end latency of your streaming setup."
echo ""

# Check if container is running
if ! docker ps | grep -q rtmp-server; then
    echo "Error: Container 'rtmp-server' is not running."
    echo "Please start it first with: ./run_docker.sh"
    exit 1
fi

# Check if ffmpeg is available
if ! command -v ffmpeg &> /dev/null; then
    echo "Warning: FFmpeg not found on host system."
    echo "You can still test using OBS Studio or other streaming software."
    echo "Stream to: rtmp://localhost:1935/live/test"
    echo ""
fi

echo "Testing server endpoints..."

# Test RTMP endpoint
echo "1. Testing RTMP endpoint (port 1935)..."
if nc -z localhost 1935 2>/dev/null; then
    echo "   ✓ RTMP port 1935 is accessible"
else
    echo "   ✗ RTMP port 1935 is not accessible"
fi

# Test HTTP endpoint
echo "2. Testing HTTP endpoint (port 8080)..."
if nc -z localhost 8080 2>/dev/null; then
    echo "   ✓ HTTP port 8080 is accessible"
else
    echo "   ✗ HTTP port 8080 is not accessible"
fi

# Test HLS endpoint
echo "3. Testing HLS endpoint..."
if curl -s http://localhost:8080/hls/ > /dev/null; then
    echo "   ✓ HLS endpoint is accessible"
else
    echo "   ✗ HLS endpoint is not accessible"
fi

echo ""
echo "=== LATENCY MEASUREMENT GUIDE ==="
echo ""
echo "To measure latency:"
echo "1. Start streaming to: rtmp://localhost:1935/live/test"
echo "2. Open player at: http://localhost:8080/players/hls.html"
echo "3. Compare timestamps between source and player"
echo ""
echo "Expected latency with optimizations:"
echo "- Before optimization: 25-30 seconds"
echo "- After optimization: 3-6 seconds"
echo ""
echo "Quick test with FFmpeg (if available):"
if command -v ffmpeg &> /dev/null; then
    echo "ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=1000:sample_rate=48000 -c:v libx264 -preset ultrafast -tune zerolatency -c:a aac -f flv rtmp://localhost:1935/live/test"
else
    echo "(Install FFmpeg to see the test command)"
fi

echo ""
echo "Monitor with:"
echo "- Server stats: http://localhost:8080/stat"
echo "- Container logs: docker logs -f rtmp-server"
echo "- System monitor: ./monitor.sh"
