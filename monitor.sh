#!/bin/bash

# Exit on error
set -e

# Check if container is running
if ! docker ps | grep -q rtmp-server; then
    echo "Container is not running. Please start it first with ./run_docker.sh"
    exit 1
fi

# Function to display menu
show_menu() {
    clear
    echo "=== RTMP/HLS Server Monitoring ==="
    echo "1. View container logs"
    echo "2. View nginx error logs"
    echo "3. View nginx access logs"
    echo "4. Monitor container resource usage"
    echo "5. Monitor HLS fragments"
    echo "6. Check nginx configuration"
    echo "7. Check running processes"
    echo "8. Enter container shell"
    echo "0. Exit"
    echo "=================================="
    echo -n "Enter your choice: "
}

# Main loop
while true; do
    show_menu
    read choice

    case $choice in
        1)
            echo "Viewing container logs (Ctrl+C to exit)..."
            docker logs -f rtmp-server
            ;;
        2)
            echo "Viewing nginx error logs (Ctrl+C to exit)..."
            docker exec rtmp-server tail -f /var/log/nginx/error.log
            ;;
        3)
            echo "Viewing nginx access logs (Ctrl+C to exit)..."
            docker exec rtmp-server tail -f /var/log/nginx/access.log
            ;;
        4)
            echo "Monitoring container resource usage (Ctrl+C to exit)..."
            docker stats rtmp-server
            ;;
        5)
            echo "Monitoring HLS fragments (Ctrl+C to exit)..."
            # Check if watch command is available
            if docker exec rtmp-server which watch &>/dev/null; then
                docker exec rtmp-server watch -n 0.5 "ls -lt /mnt/hls/ | head -20"
            else
                echo "The 'watch' command is not available in the container."
                echo "Using alternative monitoring method..."
                # Alternative method using a simple loop
                docker exec -it rtmp-server bash -c "while true; do clear; ls -lt /mnt/hls/ | head -20; sleep 1; done"
            fi
            ;;
        6)
            echo "Checking nginx configuration..."
            docker exec rtmp-server nginx -t
            echo "Current HLS fragment settings:"
            docker exec rtmp-server grep -A 10 "hls " /etc/nginx/nginx.conf
            echo "Current RTMP chunk size setting:"
            docker exec rtmp-server grep "chunk_size" /etc/nginx/nginx.conf
            echo "Press Enter to continue..."
            read
            ;;
        7)
            echo "Checking running processes..."
            docker exec rtmp-server ps aux
            echo "Press Enter to continue..."
            read
            ;;
        8)
            echo "Entering container shell (type 'exit' to return)..."
            docker exec -it rtmp-server bash
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