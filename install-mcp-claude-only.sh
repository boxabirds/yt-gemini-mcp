#!/bin/bash

# YouTube Transcript MCP Server Installer

set -e

echo "🎥 YouTube Transcript MCP Server Installer"
echo "=========================================="
echo

# Parse command line arguments
FORCE_REINSTALL=false
if [[ "$1" == "--force" ]]; then
    FORCE_REINSTALL=true
fi

# Configuration paths
MCP_DIR="$HOME/Library/Application Support/Claude/MCP"
CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
VENV_DIR="$MCP_DIR/venv"
SERVER_SCRIPT="youtube_transcript_server_fastmcp.py"

# Create MCP directory if it doesn't exist
mkdir -p "$MCP_DIR"
mkdir -p "$MCP_DIR/logs"

# Check if config file exists and has our server configured
EXISTING_KEY=""
if [[ -f "$CONFIG_FILE" ]] && ! $FORCE_REINSTALL; then
    # Try to extract existing GEMINI_API_KEY
    EXISTING_KEY=$(python3 -c "
import json
import sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
        key = config.get('mcpServers', {}).get('ask-youtube', {}).get('env', {}).get('GEMINI_API_KEY', '')
        print(key)
except:
    print('')
" 2>/dev/null || echo "")
fi

# Get API key
if [[ -n "$EXISTING_KEY" ]] && ! $FORCE_REINSTALL; then
    echo "✓ Found existing Gemini API key in configuration"
    echo "  (Use --force to enter a new key)"
    GEMINI_API_KEY="$EXISTING_KEY"
else
    echo "📝 Setting up Gemini API key for MCP server"
    echo
    echo "This MCP server needs its own Gemini API key that will be stored"
    echo "in Claude Desktop's configuration. This allows you to:"
    echo "  • Manage this key separately from your shell environment"
    echo "  • Revoke access without affecting other applications"
    echo "  • Track usage specifically for YouTube video analysis"
    echo
    echo "Get your API key at: https://aistudio.google.com/apikey"
    echo
    read -p "Enter your Gemini API key: " GEMINI_API_KEY
    
    if [[ -z "$GEMINI_API_KEY" ]]; then
        echo "❌ Error: API key cannot be empty"
        exit 1
    fi
fi

# Set up Python virtual environment
echo
echo "🐍 Setting up Python environment..."
if [[ ! -d "$VENV_DIR" ]] || $FORCE_REINSTALL; then
    python3 -m venv "$VENV_DIR"
    echo "✓ Created virtual environment"
else
    echo "✓ Using existing virtual environment"
fi

# Install dependencies
echo "📦 Installing dependencies..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet mcp fastmcp google-genai

# Copy server script
echo "📄 Installing server script..."
cp "$SERVER_SCRIPT" "$MCP_DIR/"
echo "✓ Copied $SERVER_SCRIPT to MCP directory"

# Update Claude Desktop configuration
echo
echo "⚙️  Updating Claude Desktop configuration..."

# Create or update the configuration
python3 - <<EOF
import json
import os

config_file = '$CONFIG_FILE'
api_key = '$GEMINI_API_KEY'

# Load existing config or create new one
config = {}
if os.path.exists(config_file):
    try:
        with open(config_file, 'r') as f:
            content = f.read().strip()
            if content:
                config = json.loads(content)
            else:
                print("⚠️  Config file is empty, creating new configuration")
    except json.JSONDecodeError:
        print("⚠️  Config file is corrupted, creating new configuration")

# Ensure mcpServers exists
if 'mcpServers' not in config:
    config['mcpServers'] = {}

# Add or update our server configuration
config['mcpServers']['ask-youtube'] = {
    "command": "$VENV_DIR/bin/python",
    "args": [
        "$MCP_DIR/$SERVER_SCRIPT"
    ],
    "env": {
        "GEMINI_API_KEY": api_key
    }
}

# Write the updated configuration
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✓ Updated claude_desktop_config.json")
EOF

echo
echo "✅ Installation complete!"
echo
echo "Next steps:"
echo "1. Restart Claude Desktop to load the MCP server"
echo "2. Look for 'ask-youtube' in the tool list"
echo "3. Use the 'analyze_youtube' tool to analyze videos"
echo
echo "To view logs, run: ./view_logs.sh"
echo "To manage your API key: https://aistudio.google.com/apikey"