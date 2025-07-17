#!/bin/bash

set -e

# Parse command line arguments
FORCE_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force]"
            echo "  --force: Force reinstall even if already installed"
            exit 1
            ;;
    esac
done

echo "=== Ask YouTube Transcript MCP Server Installation ==="
echo

# Detect OS
OS="Unknown"
CONFIG_PATH=""
MCP_PATH=""

if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
    CONFIG_PATH="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    MCP_PATH="$HOME/Library/Application Support/Claude/MCP"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="Windows"
    CONFIG_PATH="$APPDATA/Claude/claude_desktop_config.json"
    MCP_PATH="$APPDATA/Claude/MCP"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
    CONFIG_PATH="$HOME/.config/Claude/claude_desktop_config.json"
    MCP_PATH="$HOME/.config/Claude/MCP"
    echo "⚠️  Warning: Claude Desktop is not officially supported on Linux yet."
    echo "   Configuration paths are provided for future compatibility."
    echo
else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi

echo "Detected OS: $OS"
echo "Config path: $CONFIG_PATH"
echo "MCP path: $MCP_PATH"
echo

# Create directories if they don't exist
echo "Creating directories..."
mkdir -p "$(dirname "$CONFIG_PATH")"
mkdir -p "$MCP_PATH"

# Copy the YouTube transcript server
echo "Copying YouTube transcript server to MCP folder..."
cp youtube_transcript_server_fastmcp.py "$MCP_PATH/"
chmod +x "$MCP_PATH/youtube_transcript_server_fastmcp.py"

# Set up Python virtual environment
echo "Setting up Python virtual environment..."

VENV_PATH="$MCP_PATH/venv"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_PATH" ]; then
    echo "Creating virtual environment..."
    if command -v python3 &> /dev/null; then
        python3 -m venv "$VENV_PATH"
    elif command -v python &> /dev/null; then
        python -m venv "$VENV_PATH"
    else
        echo "❌ Error: Python not found. Please install Python first."
        exit 1
    fi
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment for installation
echo "Installing Python dependencies in virtual environment..."
"$VENV_PATH/bin/pip" install --upgrade pip > /dev/null 2>&1
"$VENV_PATH/bin/pip" install -r requirements.txt

echo "✅ Python environment ready"

# Check if already installed
check_existing_installation() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        if python3 -c "import json; config=json.load(open('$config_file')); exit(0 if 'mcpServers' in config and 'ask-youtube-transcript' in config.get('mcpServers', {}) else 1)" 2>/dev/null; then
            return 0  # Already installed
        fi
    fi
    return 1  # Not installed
}

# Check if already installed
if check_existing_installation "$CONFIG_PATH"; then
    if [ "$FORCE_INSTALL" = false ]; then
        echo "⚠️  ask-youtube-transcript is already installed in Claude Desktop config."
        echo "   Use --force to reinstall/update."
        echo
        echo "📌 Current installation:"
        python3 -c "
import json
config = json.load(open('$CONFIG_PATH'))
server = config.get('mcpServers', {}).get('ask-youtube-transcript', {})
print(f'   Command: {server.get(\"command\", \"N/A\")}')
print(f'   Args: {server.get(\"args\", [])}')
"
        exit 0
    else
        echo "🔄 Force reinstalling ask-youtube-transcript..."
    fi
fi

# Update or create claude_desktop_config.json
echo "Updating Claude Desktop configuration..."

# Function to update JSON config
update_config() {
    local config_file="$1"
    local mcp_path="$2"
    
    # Escape path for JSON (handle backslashes on Windows)
    local escaped_path=$(echo "$mcp_path" | sed 's/\\/\\\\/g')
    
    # Create new server config
    local new_server_config=$(cat <<EOF
{
  "ask-youtube-transcript": {
    "command": "$escaped_path/venv/bin/python",
    "args": ["$escaped_path/youtube_transcript_server_fastmcp.py"],
    "env": {
      "GEMINI_API_KEY": "\${GEMINI_API_KEY}"
    }
  }
}
EOF
)
    
    if [ -f "$config_file" ]; then
        # File exists, update it
        echo "Existing config found, updating..."
        
        # Check if the file has mcpServers key
        if grep -q '"mcpServers"' "$config_file"; then
            # Use Python to merge the configurations
            python3 - <<PYTHON_SCRIPT
import json
import sys

config_file = "$config_file"
new_server = $new_server_config

# Read existing config
with open(config_file, 'r') as f:
    config = json.load(f)

# Update mcpServers
if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['ask-youtube-transcript'] = new_server['ask-youtube-transcript']

# Write back
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Configuration updated successfully!")
print("   ask-youtube-transcript has been added to mcpServers")
PYTHON_SCRIPT
        else
            # Add mcpServers key
            python3 - <<PYTHON_SCRIPT
import json
import sys

config_file = "$config_file"
new_server = $new_server_config

# Read existing config
with open(config_file, 'r') as f:
    config = json.load(f)

# Add mcpServers key if it doesn't exist
if 'mcpServers' not in config:
    config['mcpServers'] = {}

# Add our server to mcpServers
config['mcpServers']['ask-youtube-transcript'] = new_server['ask-youtube-transcript']

# Write back
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Configuration updated successfully!")
print("   ask-youtube-transcript has been added to mcpServers")
PYTHON_SCRIPT
        fi
    else
        # Create new config file
        echo "Creating new config file..."
        cat > "$config_file" <<EOF
{
  "mcpServers": $new_server_config
}
EOF
        echo "✅ Configuration created successfully!"
    fi
}

# Update the configuration
update_config "$CONFIG_PATH" "$MCP_PATH"

echo
echo "=== Installation Complete! ==="
echo
echo "📌 Next steps:"
echo "1. Set your GEMINI_API_KEY environment variable:"
echo "   export GEMINI_API_KEY='your-api-key-here'"
echo "   Get your API key at: https://aistudio.google.com/apikey"
echo
echo "2. Restart Claude Desktop to load the new MCP server"
echo
echo "3. In Claude, you can now analyze YouTube videos by asking:"
echo "   'Use the analyze_youtube tool to summarize this video: [YouTube URL]'"
echo
echo "✨ Enjoy analyzing YouTube videos with Claude!"