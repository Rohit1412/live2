#!/bin/bash

# Exit on error
set -e

echo "=== RTMP/HLS Server FFmpeg Troubleshooting ==="

# Check if container is running
if ! docker ps | grep -q rtmp-server; then
    echo "Container is not running. Please start it first with ./run_docker.sh"
    exit 1
fi

# Check FFmpeg version in container
echo "Checking FFmpeg version in container..."
docker exec rtmp-server ffmpeg -version

# Check if FFmpeg can access the RTMP stream
echo "Checking if FFmpeg can access the RTMP stream..."
echo "This will attempt to connect to the RTMP stream and display information about it."
echo "Press Ctrl+C after a few seconds to stop."
docker exec rtmp-server ffmpeg -i rtmp://localhost:1935/live/stream -v debug -f null - 2>&1 | head -n 50

# Check if directories exist and have proper permissions
echo "Checking if HLS and DASH directories exist and have proper permissions..."
docker exec rtmp-server ls -la /mnt/

# Check nginx error logs for FFmpeg-related errors
echo "Checking nginx error logs for FFmpeg-related errors..."
docker exec rtmp-server grep -i ffmpeg /var/log/nginx/error.log | tail -n 20

echo "Troubleshooting complete. If you're still having issues, try the following:"
echo "1. Restart the container: docker restart rtmp-server"
echo "2. Check if your stream is being published correctly to rtmp://localhost:1935/live/stream"
echo "3. Try publishing a test stream using FFmpeg: ffmpeg -f lavfi -i testsrc=size=1280x720:rate=30 -f lavfi -i sine=frequency=1000:sample_rate=44100 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/stream"