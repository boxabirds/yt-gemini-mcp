#!/bin/bash
# YouTube Transcript MCP Server - Universal Installer (No Git Required)
# This is a completely self-contained script that can be shared as a GitHub Gist
# 
# Usage:
#   curl -sSL https://gist.github.com/YOUR_GIST_ID/raw/install-mcp-universal-no-git.sh | bash
#   OR
#   wget -qO- https://gist.github.com/YOUR_GIST_ID/raw/install-mcp-universal-no-git.sh | bash
#   OR
#   Download and run: bash install-mcp-universal-no-git.sh
#
# Supports: macOS, Linux, WSL
# Requirements: bash, jq, python3, curl or wget

set -euo pipefail

# Configuration
REPO_BASE="https://raw.githubusercontent.com/boxabirds/yt-gemini-mcp/main"
SERVER_URL="$REPO_BASE/youtube_transcript_server_fastmcp.py"
INSTALLER_VERSION="1.0.0"

# Platform-specific installation directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use Application Support
    INSTALLER_DIR="$HOME/Library/Application Support/YouTube-Transcript-MCP"
else
    # Linux/WSL - use hidden directory
    INSTALLER_DIR="$HOME/.mcp-installer"
fi
SERVERS_DIR="$INSTALLER_DIR/servers"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Detect downloader
get_downloader() {
    if command -v curl &> /dev/null; then
        echo "curl -sSL"
    elif command -v wget &> /dev/null; then
        echo "wget -qO-"
    else
        log_error "Neither curl nor wget found. Please install one:"
        echo "  macOS: brew install curl"
        echo "  Ubuntu/Debian: sudo apt-get install curl"
        echo "  RHEL/CentOS: sudo yum install curl"
        exit 1
    fi
}

# Download file
download_file() {
    local url="$1"
    local output="$2"
    local downloader=$(get_downloader)
    
    log_info "Downloading from: $url"
    
    if [[ "$downloader" == "curl"* ]]; then
        if ! curl -sSL "$url" -o "$output"; then
            log_error "Failed to download $url"
            return 1
        fi
    else
        if ! wget -qO "$output" "$url"; then
            log_error "Failed to download $url"
            return 1
        fi
    fi
    
    return 0
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    # Check for Python
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Installation instructions:"
        
        if [[ " ${missing_deps[@]} " =~ " jq " ]]; then
            echo "  jq:"
            echo "    macOS: brew install jq"
            echo "    Ubuntu/Debian: sudo apt-get install jq"
            echo "    RHEL/CentOS: sudo yum install jq"
        fi
        
        if [[ " ${missing_deps[@]} " =~ " python3 " ]]; then
            echo "  python3:"
            echo "    macOS: brew install python3"
            echo "    Ubuntu/Debian: sudo apt-get install python3"
            echo "    RHEL/CentOS: sudo yum install python3"
        fi
        
        exit 1
    fi
}

# Detect Python command
detect_python() {
    local python_cmd=""
    
    for cmd in python3 python; do
        if command -v "$cmd" &> /dev/null; then
            if "$cmd" -c "import sys; sys.exit(0 if sys.version_info.major >= 3 else 1)" 2>/dev/null; then
                python_cmd="$cmd"
                break
            fi
        fi
    done
    
    if [ -z "$python_cmd" ]; then
        log_error "Python 3 is required but not found"
        exit 1
    fi
    
    echo "$python_cmd"
}

# Detect installed clients
detect_clients() {
    local -a detected_clients=()
    
    if [ -d "$HOME/.gemini" ]; then
        detected_clients+=("gemini")
    fi
    
    # Check for Claude CLI (Claude Code)
    if command -v claude &> /dev/null; then
        detected_clients+=("claude-cli")
    fi
    
    # Check for Claude Desktop on macOS
    if [ -d "/Applications/Claude.app" ] || [ -d "$HOME/Applications/Claude.app" ]; then
        detected_clients+=("claude-desktop")
    fi
    
    if [ -d "$HOME/.codeium/windsurf" ] || \
       [ -d "$HOME/Library/Application Support/Windsurf" ] || \
       [ -d "$HOME/.config/Windsurf" ]; then
        detected_clients+=("windsurf")
    fi
    
    if [ -d "$HOME/.cursor" ]; then
        detected_clients+=("cursor")
    fi
    
    if [ ${#detected_clients[@]} -eq 0 ]; then
        return 1
    else
        printf '%s\n' "${detected_clients[@]}"
        return 0
    fi
}

# Request API key from user
request_api_key() {
    local key_name="$1"
    local prompt="$2"
    local key_value=""
    
    # Request key from user
    if [ -n "$prompt" ]; then
        echo ""
        echo "$prompt"
        echo ""
    fi
    
    # Ensure we read from the controlling terminal, not stdin
    if [ -t 0 ]; then
        read -r -p "Enter your Gemini API key: " key_value
    else
        read -r -p "Enter your Gemini API key: " key_value < /dev/tty
    fi
    
    if [ -z "$key_value" ]; then
        log_error "API key cannot be empty"
        exit 1
    fi
    
    echo "$key_value"
}

# Install for JSON-based clients
install_json_client() {
    local client="$1"
    local config_path="$2"
    local server_name="$3"
    local server_config="$4"
    
    mkdir -p "$(dirname "$config_path")"
    
    local temp_file
    temp_file=$(mktemp)
    
    local file_status="new"
    local existing_server=""
    
    if [ -f "$config_path" ]; then
        file_status="updated"
        # Check if server already exists
        existing_server=$(jq -r --arg name "$server_name" '.mcpServers[$name] // empty' "$config_path" 2>/dev/null || echo "")
        
        # Update existing config
        jq --argjson server_config "$server_config" \
           --arg server_name "$server_name" \
           '.mcpServers[$server_name] = $server_config' \
           "$config_path" > "$temp_file"
    else
        # Create new config
        jq -n --argjson server_config "$server_config" \
              --arg server_name "$server_name" \
              '{mcpServers: {($server_name): $server_config}}' > "$temp_file"
    fi
    
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$config_path"
        if [ -n "$existing_server" ]; then
            log_info "Updated existing $server_name for $client"
        else
            log_info "Installed $server_name for $client"
        fi
        echo "  📄 Config file: $config_path ($file_status)"
    else
        rm -f "$temp_file"
        log_error "Failed to create valid JSON configuration for $client"
        return 1
    fi
}

# Install for Claude Code using CLI
install_claude() {
    local server_name="$1"
    local command="$2"
    local args_json="$3"
    local env_json="$4"
    
    # Check if server already exists
    local existing_server=""
    existing_server=$(claude mcp list 2>/dev/null | grep -E "^$server_name\s" || echo "")
    
    local -a cmd=("claude" "mcp" "add" "$server_name" "-s" "user")
    
    if [ -n "$command" ]; then
        cmd+=("$command")
        
        if [ -n "$args_json" ] && [ "$args_json" != "[]" ]; then
            local -a args_array=()
            while IFS= read -r arg; do
                [ -n "$arg" ] && args_array+=("$arg")
            done < <(echo "$args_json" | jq -r '.[]' 2>/dev/null || echo "")
            
            if [ ${#args_array[@]} -gt 0 ]; then
                cmd+=("${args_array[@]}")
            fi
        fi
    fi
    
    # Set environment variables for the command
    local env_cmd=""
    if [ -n "$env_json" ] && [ "$env_json" != "{}" ]; then
        while IFS='=' read -r key value; do
            [ -n "$key" ] && env_cmd="$env_cmd $key=\"$value\""
        done < <(echo "$env_json" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' 2>/dev/null || echo "")
    fi
    
    if eval "$env_cmd" "${cmd[@]}" 2>/dev/null; then
        if [ -n "$existing_server" ]; then
            log_info "Updated existing $server_name for Claude Code"
        else
            log_info "Installed $server_name for Claude Code"
        fi
        # Claude stores configs in platform-specific locations
        local config_locations=(
            "$HOME/Library/Application Support/Code - Insiders/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
            "$HOME/.config/Code - Insiders/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
            "$HOME/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
        )
        for loc in "${config_locations[@]}"; do
            if [ -f "$loc" ]; then
                echo "  📄 Config file: $loc"
                break
            fi
        done
        return 0
    else
        log_error "Failed to install for Claude Code"
        log_warn "You may need to install manually using: claude mcp add"
        return 1
    fi
}

# Download and install server
download_and_install_server() {
    local server_url="$1"
    local server_path="$2"
    
    # Try multiple sources if the first fails
    local sources=(
        "$server_url"
        "https://cdn.jsdelivr.net/gh/boxabirds/yt-gemini-mcp@main/youtube_transcript_server_fastmcp.py"
        "https://gitcdn.link/repo/boxabirds/yt-gemini-mcp/main/youtube_transcript_server_fastmcp.py"
    )
    
    local downloaded=false
    for source in "${sources[@]}"; do
        if download_file "$source" "$server_path"; then
            downloaded=true
            break
        fi
    done
    
    if [ "$downloaded" = false ]; then
        log_error "Failed to download server from all sources"
        exit 1
    fi
    
    # Make executable
    chmod +x "$server_path"
    
    # Verify it's valid Python
    local python_cmd
    python_cmd=$(detect_python)
    if ! "$python_cmd" -m py_compile "$server_path" 2>/dev/null; then
        log_error "Downloaded server script has syntax errors"
        rm -f "$server_path"
        exit 1
    fi
}

# Create virtual environment
create_venv() {
    local venv_dir="$1"
    local python_cmd="$2"
    
    if [ ! -d "$venv_dir" ]; then
        log_info "Creating virtual environment..."
        if "$python_cmd" -m venv "$venv_dir"; then
            log_info "Created virtual environment at $venv_dir"
        else
            log_error "Failed to create virtual environment"
            return 1
        fi
    else
        log_info "Using existing virtual environment at $venv_dir"
    fi
    
    # Upgrade pip in the venv
    if "$venv_dir/bin/python" -m pip install --quiet --upgrade pip; then
        return 0
    else
        log_warn "Failed to upgrade pip in virtual environment"
        return 1
    fi
}

# Install Python dependencies in virtual environment
install_python_deps() {
    local venv_dir="$1"
    local python_cmd="$2"
    
    log_info "Installing Python dependencies in virtual environment..."
    
    # Create a temporary requirements file
    local temp_requirements=$(mktemp)
    cat > "$temp_requirements" << 'EOF'
mcp>=1.0.0
fastmcp>=0.1.0
google-genai>=0.8.0
EOF
    
    # Install dependencies in venv
    if "$venv_dir/bin/pip" install --quiet -r "$temp_requirements"; then
        log_info "Python dependencies installed successfully"
        rm -f "$temp_requirements"
        return 0
    else
        log_warn "Failed to install some Python dependencies"
        echo "You may need to install them manually:"
        echo "  $venv_dir/bin/pip install mcp fastmcp google-genai"
        rm -f "$temp_requirements"
        return 1
    fi
}

# Main installation
main() {
    log_info "YouTube Transcript MCP Server Installer v$INSTALLER_VERSION"
    echo "=================================================="
    
    # Check dependencies
    check_dependencies
    
    # Get Gemini API key
    echo "📝 Setting up Gemini API key for MCP server"
    echo ""
    echo "This MCP server needs its own Gemini API key that will be stored"
    echo "in each AI assistant's configuration. This allows you to:"
    echo "  • Manage this key separately from your shell environment"
    echo "  • Revoke access without affecting other applications"
    echo "  • Track usage specifically for YouTube video analysis"
    echo ""
    echo "Get your API key at: https://aistudio.google.com/apikey"
    
    local gemini_key
    gemini_key=$(request_api_key "GEMINI_API_KEY" "")
    
    # Detect Python
    local python_cmd
    python_cmd=$(detect_python)
    log_info "Found Python: $python_cmd"
    
    # Create directories
    mkdir -p "$SERVERS_DIR"
    
    # Download server
    log_info "Downloading MCP server..."
    local server_script="$SERVERS_DIR/youtube_transcript_server.py"
    
    # Check if server already exists
    local server_status="new"
    if [ -f "$server_script" ]; then
        server_status="updated"
    fi
    
    download_and_install_server "$SERVER_URL" "$server_script"
    echo "  📄 Server script: $server_script ($server_status)"
    
    # Create virtual environment
    local venv_dir="$INSTALLER_DIR/venv"
    create_venv "$venv_dir" "$python_cmd"
    echo "  📄 Virtual environment: $venv_dir"
    
    # Install Python dependencies
    install_python_deps "$venv_dir" "$python_cmd"
    
    # Use venv Python for running the server
    local venv_python="$venv_dir/bin/python"
    
    # Detect installed clients
    log_info "Detecting installed AI assistants..."
    local -a clients=()
    while IFS= read -r client; do
        clients+=("$client")
    done < <(detect_clients || true)
    
    if [ ${#clients[@]} -eq 0 ]; then
        log_error "No supported AI assistants detected"
        echo ""
        echo "Supported clients:"
        echo "  - Gemini CLI"
        echo "  - Claude Code (CLI)"
        echo "  - Claude Desktop"
        echo "  - Windsurf"
        echo "  - Cursor"
        exit 1
    fi
    
    log_info "Found ${#clients[@]} client(s): ${clients[*]}"
    
    # Install for each client
    local success_count=0
    for client in "${clients[@]}"; do
        echo ""
        log_info "Configuring $client..."
        
        case "$client" in
            "gemini")
                local config_path="$HOME/.gemini/settings.json"
                local server_config
                server_config=$(jq -n \
                    --arg cmd "$venv_python" \
                    --arg script "$server_script" \
                    --arg key "$gemini_key" \
                    '{
                        command: $cmd,
                        args: [$script],
                        env: {
                            GEMINI_API_KEY: $key
                        }
                    }')
                if install_json_client "$client" "$config_path" "youtube-transcript" "$server_config"; then
                    ((success_count++))
                fi
                ;;
                
            "claude-cli")
                if install_claude "youtube-transcript" "$venv_python" "[\"$server_script\"]" "{\"GEMINI_API_KEY\": \"$gemini_key\"}"; then
                    ((success_count++))
                fi
                ;;
                
            "claude-desktop")
                local config_path="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
                local server_config
                server_config=$(jq -n \
                    --arg cmd "$venv_python" \
                    --arg script "$server_script" \
                    --arg key "$gemini_key" \
                    '{
                        command: $cmd,
                        args: [$script],
                        env: {
                            GEMINI_API_KEY: $key
                        }
                    }')
                if install_json_client "$client" "$config_path" "youtube-transcript" "$server_config"; then
                    ((success_count++))
                fi
                ;;
                
            "windsurf")
                local config_path
                if [ -d "$HOME/Library/Application Support/Windsurf" ]; then
                    config_path="$HOME/Library/Application Support/Windsurf/mcp_config.json"
                elif [ -d "$HOME/.config/Windsurf" ]; then
                    config_path="$HOME/.config/Windsurf/mcp_config.json"
                else
                    config_path="$HOME/.codeium/windsurf/mcp_config.json"
                fi
                
                local server_config
                server_config=$(jq -n \
                    --arg cmd "$venv_python" \
                    --arg script "$server_script" \
                    --arg key "$gemini_key" \
                    '{
                        command: $cmd,
                        args: [$script],
                        env: {
                            GEMINI_API_KEY: $key
                        }
                    }')
                if install_json_client "$client" "$config_path" "youtube-transcript" "$server_config"; then
                    ((success_count++))
                fi
                ;;
                
            "cursor")
                local config_path="$HOME/.cursor/mcp.json"
                local server_config
                server_config=$(jq -n \
                    --arg cmd "$venv_python" \
                    --arg script "$server_script" \
                    --arg key "$gemini_key" \
                    '{
                        command: $cmd,
                        args: [$script],
                        env: {
                            GEMINI_API_KEY: $key
                        }
                    }')
                if install_json_client "$client" "$config_path" "youtube-transcript" "$server_config"; then
                    ((success_count++))
                fi
                ;;
        esac
    done
    
    # Create test script
    create_test_script "$venv_python" "$server_script" "$gemini_key"
    
    echo ""
    if [ $success_count -gt 0 ]; then
        log_info "Installation complete! ($success_count/${#clients[@]} clients configured)"
        echo ""
        echo "Next steps:"
        echo "1. Restart any running AI assistant applications"
        echo "2. The server will be available as 'youtube-transcript' in configured clients"
        echo "3. Test the server with: $INSTALLER_DIR/test-server.sh"
        
        if [ $success_count -lt ${#clients[@]} ]; then
            echo ""
            log_warn "Some clients failed to configure. Check the errors above."
        fi
    else
        log_error "Installation failed for all clients"
        exit 1
    fi
}

# Create test script
create_test_script() {
    local python_cmd="$1"
    local server_script="$2"
    local api_key="$3"
    
    local test_script="$INSTALLER_DIR/test-server.sh"
    
    cat > "$test_script" << EOF
#!/bin/bash
# YouTube Transcript MCP Server Test Script
# WARNING: This script contains your API key in plain text

export GEMINI_API_KEY="$api_key"
echo "Testing YouTube Transcript MCP Server..."
echo "Press Ctrl+C to stop"
echo ""
exec "$python_cmd" "$server_script"
EOF
    
    chmod +x "$test_script"
}

# Run main
main "$@"