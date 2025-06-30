#!/bin/bash

echo "=== HLS SEGMENT SYNCHRONIZATION TROUBLESHOOTING ==="
echo ""

# Check if container is running
if ! docker ps | grep -q rtmp-server; then
    echo "❌ Container 'rtmp-server' is not running"
    echo "   Solution: Run ./run_docker.sh to start the container"
    exit 1
else
    echo "✅ Container 'rtmp-server' is running"
fi

# Check nginx process
if docker exec rtmp-server pgrep nginx > /dev/null; then
    echo "✅ Nginx is running inside container"
else
    echo "❌ Nginx is not running inside container"
    echo "   Checking nginx error log:"
    docker exec rtmp-server tail -10 /var/log/nginx/error.log
    echo "   Solution: Try restarting the container"
    exit 1
fi

# Check HLS directory and segments
echo ""
echo "Checking HLS directory and segments..."
if docker exec rtmp-server test -d /mnt/hls; then
    echo "✅ HLS directory exists"
    echo "   Current segments:"
    docker exec rtmp-server find /mnt/hls -name "*.ts" -o -name "*.m3u8" | head -10
    echo "   Total segments: $(docker exec rtmp-server find /mnt/hls -name "*.ts" | wc -l)"
    echo "   Playlists: $(docker exec rtmp-server find /mnt/hls -name "*.m3u8" | wc -l)"
    
    # Check segment timestamps
    echo "   Recent segment timestamps:"
    docker exec rtmp-server ls -lt /mnt/hls/*.ts 2>/dev/null | head -5 || echo "   No .ts files found"
else
    echo "❌ HLS directory does not exist"
    echo "   Solution: Run docker exec rtmp-server mkdir -p /mnt/hls"
fi

# Check for active streams
echo ""
echo "Checking for active streams..."
ACTIVE_STREAMS=$(docker exec rtmp-server curl -s http://localhost:8080/stat | grep -o '<name>[^<]*</name>' | sed 's/<[^>]*>//g' | grep -v '^$' || echo "")
if [ -n "$ACTIVE_STREAMS" ]; then
    echo "✅ Active streams found:"
    echo "$ACTIVE_STREAMS"
else
    echo "⚠️  No active streams detected"
    echo "   Start streaming to: rtmp://localhost:1935/live/your_stream_name"
fi

# Check recent nginx errors related to HLS
echo ""
echo "Checking recent HLS-related errors..."
RECENT_ERRORS=$(docker exec rtmp-server tail -50 /var/log/nginx/error.log | grep -i "hls\|segment\|playlist" | tail -5)
if [ -n "$RECENT_ERRORS" ]; then
    echo "⚠️  Recent HLS errors found:"
    echo "$RECENT_ERRORS"
else
    echo "✅ No recent HLS errors in nginx log"
fi

# Check current configuration
echo ""
echo "=== Current HLS Configuration ==="
echo "HLS fragment size:"
docker exec rtmp-server grep "hls_fragment" /etc/nginx/nginx.conf || echo "Not found"
echo "HLS playlist length:"
docker exec rtmp-server grep "hls_playlist_length" /etc/nginx/nginx.conf || echo "Not found"
echo "HLS cleanup:"
docker exec rtmp-server grep "hls_cleanup" /etc/nginx/nginx.conf || echo "Not found"
echo "HLS sync:"
docker exec rtmp-server grep "hls_sync" /etc/nginx/nginx.conf || echo "Not found"

# Check FFmpeg processes
echo ""
echo "Checking FFmpeg processes..."
FFMPEG_PROCS=$(docker exec rtmp-server pgrep -f ffmpeg | wc -l)
echo "Active FFmpeg processes: $FFMPEG_PROCS"
if [ "$FFMPEG_PROCS" -gt 0 ]; then
    echo "FFmpeg command lines:"
    docker exec rtmp-server pgrep -f ffmpeg -a | head -3
fi

echo ""
echo "=== Segment Sync Diagnostics ==="
if docker exec rtmp-server test -f /mnt/hls/stream_low.m3u8; then
    echo "Sample playlist content (last 10 lines):"
    docker exec rtmp-server tail -10 /mnt/hls/stream_low.m3u8
    
    # Check for segment gaps
    echo ""
    echo "Checking for segment sequence gaps..."
    SEGMENTS=$(docker exec rtmp-server grep -o 'stream_low-[0-9]*\.ts' /mnt/hls/stream_low.m3u8 | grep -o '[0-9]*' | sort -n)
    if [ -n "$SEGMENTS" ]; then
        echo "Segment numbers in playlist: $(echo $SEGMENTS | tr '\n' ' ')"
        # Check for missing segments
        FIRST=$(echo $SEGMENTS | head -1)
        LAST=$(echo $SEGMENTS | tail -1)
        EXPECTED_COUNT=$((LAST - FIRST + 1))
        ACTUAL_COUNT=$(echo $SEGMENTS | wc -w)
        if [ "$EXPECTED_COUNT" -eq "$ACTUAL_COUNT" ]; then
            echo "✅ No segment gaps detected"
        else
            echo "⚠️  Segment gaps detected: Expected $EXPECTED_COUNT, found $ACTUAL_COUNT"
        fi
    fi
else
    echo "No playlist found - stream may not be active"
fi

# Test segment accessibility
echo ""
echo "Testing segment accessibility..."
LATEST_SEGMENT=$(docker exec rtmp-server find /mnt/hls -name "*.ts" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- | xargs basename 2>/dev/null || echo "")
if [ -n "$LATEST_SEGMENT" ]; then
    echo "Testing latest segment: $LATEST_SEGMENT"
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/hls/$LATEST_SEGMENT" | grep -q "200"; then
        echo "✅ Latest segment is accessible via HTTP"
    else
        echo "❌ Latest segment is not accessible via HTTP"
    fi
else
    echo "No segments found to test"
fi

echo ""
echo "=== RECOMMENDED ACTIONS ==="
if [ "$FFMPEG_PROCS" -eq 0 ]; then
    echo "1. No active streams - start streaming to rtmp://localhost:1935/live/test"
elif docker exec rtmp-server find /mnt/hls -name "*.ts" | wc -l | grep -q "^0$"; then
    echo "1. Segments not being generated - check FFmpeg configuration"
    echo "   Run: ./fix_segment_sync.sh"
elif [ -n "$RECENT_ERRORS" ]; then
    echo "1. HLS errors detected - check nginx configuration"
    echo "   Run: ./fix_segment_sync.sh"
else
    echo "1. Configuration looks good - test with a player"
    echo "   URL: http://localhost:8080/players/hls.html"
fi

echo ""
echo "Quick fixes:"
echo "• For 404 errors: ./fix_segment_sync.sh"
echo "• For high latency: ./optimize_latency.sh"
echo "• To restart fresh: docker restart rtmp-server"
echo "• To view live logs: docker logs -f rtmp-server"

echo ""
echo "=== Troubleshooting Complete ==="
