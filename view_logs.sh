#!/bin/bash

# Script to view MCP server logs

LOG_DIR="$HOME/Library/Application Support/Claude/MCP/logs"

echo "=== MCP Server Logs ==="
echo "Log directory: $LOG_DIR"
echo

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    echo "📁 Creating log directory..."
    mkdir -p "$LOG_DIR"
fi

# Find the most recent log file
LATEST_LOG=$(ls -t "$LOG_DIR"/ask_youtube_transcript_*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
    echo "⏳ No log files found yet. Waiting for MCP server to start..."
    echo "   (Restart Claude Desktop to trigger server startup)"
    echo
    echo "Watching for new log files..."
    
    # Wait for a log file to appear
    while [ -z "$LATEST_LOG" ]; do
        sleep 1
        LATEST_LOG=$(ls -t "$LOG_DIR"/ask_youtube_transcript_*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            echo
            echo "✅ Log file created: $(basename "$LATEST_LOG")"
            break
        fi
    done
fi

echo "Latest log file: $(basename "$LATEST_LOG")"
echo "Created: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LATEST_LOG")"
echo
echo "=== Log Contents ==="
echo

# Function to colorize log lines
colorize_log() {
    while IFS= read -r line; do
        if [[ $line == *"ERROR"* ]]; then
            echo -e "\033[0;31m$line\033[0m"  # Red for errors
        elif [[ $line == *"WARNING"* ]]; then
            echo -e "\033[0;33m$line\033[0m"  # Yellow for warnings
        elif [[ $line == *"INFO"* ]]; then
            echo -e "\033[0;32m$line\033[0m"  # Green for info
        elif [[ $line == *"DEBUG"* ]]; then
            echo -e "\033[0;36m$line\033[0m"  # Cyan for debug
        else
            echo "$line"
        fi
    done
}

# Show initial content
if [ -s "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | colorize_log
    echo
    echo "--- Following log file for new entries ---"
fi

# Follow the log
tail -f "$LATEST_LOG" | colorize_log