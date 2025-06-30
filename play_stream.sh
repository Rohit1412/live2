#!/bin/bash

# Exit on error
set -e

echo "=== RTMP/HLS Stream Player ==="
echo "This script helps you play streams using FFplay with different quality settings."
echo ""

# Check if ffplay is installed
if ! command -v ffplay &> /dev/null; then
    echo "Error: ffplay is not installed."
    echo "Please install it with: sudo apt-get install ffmpeg"
    exit 1
fi

# Function to display menu
show_menu() {
    clear
    echo "=== RTMP/HLS Stream Player ==="
    echo "1. Play RTMP stream"
    echo "2. Play HLS stream"
    echo "3. Play HLS stream with specific quality"
    echo "4. Play RTMP stream with low latency settings"
    echo "5. Play HLS stream with low latency settings"
    echo "6. List available streams"
    echo "0. Exit"
    echo "=================================="
    echo -n "Enter your choice: "
}

# Function to play RTMP stream
play_rtmp() {
    local stream_key=$1
    echo "Playing RTMP stream: rtmp://localhost:1935/live/$stream_key"
    ffplay -fflags nobuffer -flags low_delay -framedrop -strict experimental rtmp://localhost:1935/live/$stream_key
}

# Function to play HLS stream
play_hls() {
    local stream_key=$1
    echo "Playing HLS stream: http://localhost:8080/hls/$stream_key.m3u8"
    ffplay -fflags nobuffer -flags low_delay -framedrop http://localhost:8080/hls/$stream_key.m3u8
}

# Function to play HLS stream with specific quality
play_hls_quality() {
    local stream_key=$1
    local quality=$2
    echo "Playing HLS stream with quality $quality: http://localhost:8080/hls/$stream_key\_$quality.m3u8"
    ffplay -fflags nobuffer -flags low_delay -framedrop http://localhost:8080/hls/$stream_key\_$quality.m3u8
}

# Function to play RTMP stream with low latency settings
play_rtmp_low_latency() {
    local stream_key=$1
    echo "Playing RTMP stream with low latency settings: rtmp://localhost:1935/live/$stream_key"
    ffplay -fflags nobuffer -flags low_delay -framedrop -probesize 32 -analyzeduration 0 -sync ext rtmp://localhost:1935/live/$stream_key
}

# Function to play HLS stream with low latency settings
play_hls_low_latency() {
    local stream_key=$1
    echo "Playing HLS stream with low latency settings: http://localhost:8080/hls/$stream_key.m3u8"
    ffplay -fflags nobuffer -flags low_delay -framedrop -probesize 32 -analyzeduration 0 -sync ext http://localhost:8080/hls/$stream_key.m3u8
}

# Function to list available streams
list_streams() {
    echo "Checking for available streams..."
    
    # Check if container is running
    if ! docker ps | grep -q rtmp-server; then
        echo "Container is not running. Please start it first with ./run_docker.sh"
        return
    fi
    
    echo "RTMP Streams:"
    docker exec rtmp-server curl -s http://localhost:8080/stat | grep -o 'name>[^<]*' | sed 's/name>//'
    
    echo "HLS Streams:"
    docker exec rtmp-server ls -1 /mnt/hls/ | grep -o '^[^_]*\.m3u8' | sed 's/\.m3u8//'
}

# Main loop
while true; do
    show_menu
    read choice
    
    case $choice in
        1)
            echo "Enter stream key (default: stream):"
            read -r stream_key
            stream_key=${stream_key:-stream}
            play_rtmp "$stream_key"
            ;;
        2)
            echo "Enter stream key (default: stream):"
            read -r stream_key
            stream_key=${stream_key:-stream}
            play_hls "$stream_key"
            ;;
        3)
            echo "Enter stream key (default: stream):"
            read -r stream_key
            stream_key=${stream_key:-stream}
            
            echo "Select quality:"
            echo "1. 720p"
            echo "2. 480p"
            echo "3. 360p"
            echo "4. 240p"
            read -r quality_choice
            
            case $quality_choice in
                1) quality="720p" ;;
                2) quality="480p" ;;
                3) quality="360p" ;;
                4) quality="240p" ;;
                *) quality="720p" ;;
            esac
            
            play_hls_quality "$stream_key" "$quality"
            ;;
        4)
            echo "Enter stream key (default: stream):"
            read -r stream_key
            stream_key=${stream_key:-stream}
            play_rtmp_low_latency "$stream_key"
            ;;
        5)
            echo "Enter stream key (default: stream):"
            read -r stream_key
            stream_key=${stream_key:-stream}
            play_hls_low_latency "$stream_key"
            ;;
        6)
            list_streams
            echo "Press Enter to continue..."
            read
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Press Enter to continue..."
            read
            ;;
    esac
done