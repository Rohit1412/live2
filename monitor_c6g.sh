#!/bin/bash

# Make script executable
chmod +x "$0" 2>/dev/null

# c6g.xlarge RTMP/HLS Performance Monitor
# Optimized for AWS Graviton2 with 6 quality levels

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Thresholds
CPU_WARNING=80
CPU_CRITICAL=90
MEM_WARNING=75
MEM_CRITICAL=85

clear
echo -e "${BLUE}=== AWS c6g.xlarge RTMP/HLS Monitor ===${NC}"
echo -e "${BLUE}Graviton2 ARM64 - 4 vCPU, 8GB RAM${NC}"
echo "Timestamp: $(date)"
echo "Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
echo ""

# System Resources
echo -e "${BLUE}=== System Resources ===${NC}"

# CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
CPU_INT=$(echo $CPU_USAGE | cut -d'.' -f1)

if [ "$CPU_INT" -gt "$CPU_CRITICAL" ]; then
    CPU_COLOR=$RED
    CPU_STATUS="CRITICAL"
elif [ "$CPU_INT" -gt "$CPU_WARNING" ]; then
    CPU_COLOR=$YELLOW
    CPU_STATUS="WARNING"
else
    CPU_COLOR=$GREEN
    CPU_STATUS="OK"
fi

echo -e "CPU Usage: ${CPU_COLOR}${CPU_USAGE}% (${CPU_STATUS})${NC}"

# Load Average
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
echo "Load Average: $LOAD_AVG (1min, 5min, 15min)"

# Memory Usage
MEM_INFO=$(free | grep Mem)
MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
MEM_PERCENT=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc)
MEM_INT=$(echo $MEM_PERCENT | cut -d'.' -f1)

if [ "$MEM_INT" -gt "$MEM_CRITICAL" ]; then
    MEM_COLOR=$RED
    MEM_STATUS="CRITICAL"
elif [ "$MEM_INT" -gt "$MEM_WARNING" ]; then
    MEM_COLOR=$YELLOW
    MEM_STATUS="WARNING"
else
    MEM_COLOR=$GREEN
    MEM_STATUS="OK"
fi

MEM_USED_GB=$(echo "scale=1; $MEM_USED / 1024 / 1024" | bc)
MEM_TOTAL_GB=$(echo "scale=1; $MEM_TOTAL / 1024 / 1024" | bc)

echo -e "Memory: ${MEM_COLOR}${MEM_USED_GB}GB/${MEM_TOTAL_GB}GB (${MEM_PERCENT}% - ${MEM_STATUS})${NC}"

# Disk Usage
DISK_INFO=$(df -h / | tail -1)
DISK_USAGE=$(echo $DISK_INFO | awk '{print $5}' | sed 's/%//')
DISK_USED=$(echo $DISK_INFO | awk '{print $3}')
DISK_TOTAL=$(echo $DISK_INFO | awk '{print $2}')

if [ "$DISK_USAGE" -gt 85 ]; then
    DISK_COLOR=$RED
elif [ "$DISK_USAGE" -gt 75 ]; then
    DISK_COLOR=$YELLOW
else
    DISK_COLOR=$GREEN
fi

echo -e "Disk Usage: ${DISK_COLOR}${DISK_USED}/${DISK_TOTAL} (${DISK_USAGE}%)${NC}"

# Docker Storage
if [ -d "/var/lib/docker" ]; then
    DOCKER_SIZE=$(du -sh /var/lib/docker 2>/dev/null | awk '{print $1}')
    echo "Docker Storage: $DOCKER_SIZE"
fi

echo ""

# Container Status
echo -e "${BLUE}=== Container Status ===${NC}"

if docker ps | grep -q rtmp; then
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep rtmp | head -1)
    echo -e "${GREEN}Container: $CONTAINER_NAME (Running)${NC}"
    
    # Container stats
    CONTAINER_STATS=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" $CONTAINER_NAME 2>/dev/null)
    if [ ! -z "$CONTAINER_STATS" ]; then
        CONTAINER_CPU=$(echo $CONTAINER_STATS | awk '{print $1}' | sed 's/%//')
        CONTAINER_MEM=$(echo $CONTAINER_STATS | awk '{print $2}')
        echo "Container CPU: ${CONTAINER_CPU}%"
        echo "Container Memory: $CONTAINER_MEM"
    fi
else
    echo -e "${RED}Container: Not running${NC}"
fi

echo ""

# FFmpeg Processes
echo -e "${BLUE}=== Video Encoding Status ===${NC}"

if docker ps | grep -q rtmp; then
    FFMPEG_COUNT=$(docker exec $CONTAINER_NAME ps aux 2>/dev/null | grep ffmpeg | grep -v grep | wc -l)
    
    if [ "$FFMPEG_COUNT" -gt 0 ]; then
        echo -e "${GREEN}FFmpeg Processes: $FFMPEG_COUNT active${NC}"
        
        # Show FFmpeg processes with quality levels
        echo "Active Encoding Processes:"
        docker exec $CONTAINER_NAME ps aux 2>/dev/null | grep ffmpeg | grep -v grep | while read line; do
            if echo "$line" | grep -q "_low"; then
                echo "  • 360p (Low Quality)"
            elif echo "$line" | grep -q "_mid"; then
                echo "  • 480p (Medium Quality)"
            elif echo "$line" | grep -q "_high"; then
                echo "  • 720p (High Quality)"
            elif echo "$line" | grep -q "_hd720"; then
                echo "  • 1080p (HD Quality)"
            elif echo "$line" | grep -q "_hd1080"; then
                echo "  • 1440p (QHD Quality)"
            elif echo "$line" | grep -q "_hd2160"; then
                echo -e "  • ${YELLOW}4K (Ultra Quality)${NC}"
            fi
        done
        
        # Expected processes per stream
        if [ "$FFMPEG_COUNT" -eq 6 ]; then
            echo -e "${GREEN}✓ All 6 quality levels active (1 stream)${NC}"
        elif [ "$FFMPEG_COUNT" -eq 12 ]; then
            echo -e "${YELLOW}⚠ 12 processes detected (2 streams - HIGH CPU LOAD)${NC}"
        elif [ "$FFMPEG_COUNT" -gt 12 ]; then
            echo -e "${RED}⚠ $FFMPEG_COUNT processes (OVERLOADED - REDUCE STREAMS)${NC}"
        fi
    else
        echo "FFmpeg Processes: None (No active streams)"
    fi
else
    echo "Cannot check FFmpeg processes (container not running)"
fi

echo ""

# Network Status
echo -e "${BLUE}=== Network Connections ===${NC}"

RTMP_CONNECTIONS=$(netstat -an 2>/dev/null | grep :1935 | grep ESTABLISHED | wc -l)
HLS_CONNECTIONS=$(netstat -an 2>/dev/null | grep :8080 | grep ESTABLISHED | wc -l)

echo "RTMP Connections: $RTMP_CONNECTIONS (Publishers)"
echo "HLS Connections: $HLS_CONNECTIONS (Viewers)"

# Network throughput
if command -v vnstat >/dev/null 2>&1; then
    NETWORK_INFO=$(vnstat -i eth0 --json | jq -r '.interfaces[0].traffic.hour[-1] | "RX: \(.rx)MB TX: \(.tx)MB"' 2>/dev/null)
    if [ ! -z "$NETWORK_INFO" ]; then
        echo "Network (last hour): $NETWORK_INFO"
    fi
fi

echo ""

# Stream Statistics
echo -e "${BLUE}=== Stream Statistics ===${NC}"

if curl -s http://localhost:8080/stat >/dev/null 2>&1; then
    # Parse RTMP statistics
    STATS=$(curl -s http://localhost:8080/stat 2>/dev/null)
    
    if echo "$STATS" | grep -q "<live>"; then
        echo "RTMP Server: Active"
        
        # Extract stream information
        STREAM_COUNT=$(echo "$STATS" | grep -o "<stream>" | wc -l)
        echo "Active Streams: $STREAM_COUNT"
        
        if [ "$STREAM_COUNT" -gt 0 ]; then
            echo "Stream Details:"
            echo "$STATS" | grep -E "(name|bw_in|bw_out|bytes_in|bytes_out)" | head -10 | while read line; do
                if echo "$line" | grep -q "name"; then
                    STREAM_NAME=$(echo "$line" | sed 's/<[^>]*>//g' | xargs)
                    echo "  Stream: $STREAM_NAME"
                elif echo "$line" | grep -q "bw_in"; then
                    BW_IN=$(echo "$line" | sed 's/<[^>]*>//g' | xargs)
                    echo "    Input: ${BW_IN} bps"
                elif echo "$line" | grep -q "bw_out"; then
                    BW_OUT=$(echo "$line" | sed 's/<[^>]*>//g' | xargs)
                    echo "    Output: ${BW_OUT} bps"
                fi
            done
        fi
    else
        echo "RTMP Server: No active streams"
    fi
else
    echo -e "${RED}Cannot connect to statistics endpoint${NC}"
fi

echo ""

# Health Checks
echo -e "${BLUE}=== Health Checks ===${NC}"

# Check if HLS endpoint is responding
if curl -s -I http://localhost:8080/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ HTTP Server responding${NC}"
else
    echo -e "${RED}✗ HTTP Server not responding${NC}"
fi

# Check if RTMP port is listening
if netstat -ln 2>/dev/null | grep -q :1935; then
    echo -e "${GREEN}✓ RTMP Port (1935) listening${NC}"
else
    echo -e "${RED}✗ RTMP Port (1935) not listening${NC}"
fi

# Check disk space for streaming
HLS_DISK_USAGE=$(df /mnt 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
if [ "$HLS_DISK_USAGE" -gt 80 ]; then
    echo -e "${RED}✗ HLS Storage almost full (${HLS_DISK_USAGE}%)${NC}"
elif [ "$HLS_DISK_USAGE" -gt 60 ]; then
    echo -e "${YELLOW}⚠ HLS Storage usage: ${HLS_DISK_USAGE}%${NC}"
else
    echo -e "${GREEN}✓ HLS Storage OK (${HLS_DISK_USAGE}%)${NC}"
fi

echo ""

# Performance Recommendations
echo -e "${BLUE}=== Performance Recommendations ===${NC}"

if [ "$CPU_INT" -gt 90 ]; then
    echo -e "${RED}⚠ CPU CRITICAL: Consider reducing quality levels or concurrent streams${NC}"
elif [ "$CPU_INT" -gt 80 ]; then
    echo -e "${YELLOW}⚠ CPU HIGH: Monitor closely, may need to reduce load${NC}"
fi

if [ "$MEM_INT" -gt 80 ]; then
    echo -e "${YELLOW}⚠ Memory usage high, consider restarting container${NC}"
fi

if [ "$FFMPEG_COUNT" -gt 6 ]; then
    echo -e "${YELLOW}⚠ Multiple streams detected - c6g.xlarge may struggle with 4K${NC}"
fi

if [ "$RTMP_CONNECTIONS" -eq 0 ] && [ "$FFMPEG_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ FFmpeg processes running but no RTMP connections${NC}"
fi

echo ""
echo -e "${BLUE}=== Quick Commands ===${NC}"
echo "Monitor logs: docker logs -f $CONTAINER_NAME"
echo "Restart container: docker restart $CONTAINER_NAME"
echo "View detailed stats: curl http://localhost:8080/stat"
echo "Test stream: ffmpeg -re -f lavfi -i testsrc2=size=1280x720:rate=30 -c:v libx264 -preset ultrafast -f flv rtmp://localhost:1935/live/test"
