# Multi-Client MCP Server Installer Plan (Native Shell Scripts) - FIXED VERSION

## Overview

This document contains the fixed implementation of a native shell script for a universal MCP server installer that:
1. Uses PowerShell on Windows and Bash on macOS/Linux
2. Installs MCP servers at the account/user level across all supported clients
3. Handles API key management with single-entry configuration (stored in plain text)
4. Embeds the MCP server script within the installer for true self-contained distribution
5. Requires only standard system utilities plus:
   - Unix/Linux/macOS: `jq` for JSON processing
   - Windows: PowerShell 5.0+ (pre-installed on Windows 10+)
   - Python 3.x for running the embedded MCP server

## Architecture

### Core Components

1. **Embedded Server**: MCP server script embedded as base64 within installer
2. **Configuration Manager**: JSON manipulation using jq (Unix) or PowerShell cmdlets (Windows)
3. **Key Manager**: Plain text key storage with restrictive file permissions
4. **Client Detector**: File system and command checks for installed clients
5. **Server Installer**: Client-specific configuration updates

### File Structure
```
mcp-universal-installer/
├── install.sh              # Unix/Linux/macOS installer (self-contained)
├── install.ps1             # Windows PowerShell installer (self-contained)
├── install.cmd             # Windows batch file wrapper
└── README.md               # Installation instructions
```

## Implementation Details

### 1. Cross-Platform Entry Point (`install.cmd`)

```batch
@echo off
REM Universal MCP Installer - Windows Entry Point

REM Check if PowerShell is available
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: PowerShell is required but not found
    echo Please install PowerShell 5.0 or higher
    exit /b 1
)

REM Check PowerShell version - FIXED
for /f %%i in ('powershell -Command "$PSVersionTable.PSVersion.Major"') do set PS_MAJOR=%%i
if %PS_MAJOR% LSS 5 (
    echo Error: PowerShell 5.0 or higher is required
    echo Current version is too old
    exit /b 1
)

REM Run PowerShell installer with bypass policy
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1" %*
```

### 2. Bash Installer (`install.sh`)

```bash
#!/bin/bash
# Universal MCP Server Installer for Unix-like systems
# Self-contained installer with embedded server

set -euo pipefail

# Configuration
INSTALLER_VERSION="2.0.0"
INSTALLER_DIR="$HOME/.mcp-installer"
KEYS_FILE="$INSTALLER_DIR/keys.json"
SERVERS_DIR="$INSTALLER_DIR/servers"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Embedded MCP server script (base64 encoded)
# To update: base64 -w0 youtube_transcript_server.py > server_base64.txt
read -r -d '' EMBEDDED_SERVER_BASE64 << 'EOF' || true
IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwojIFlvdVR1YmUgVHJhbnNjcmlwdCBNQ1AgU2VydmVy
CiMgRXhhbXBsZSBzZXJ2ZXIgLSByZXBsYWNlIHdpdGggYWN0dWFsIGNvZGUKCmltcG9ydCBv
cwppbXBvcnQganNvbgppbXBvcnQgc3lzCgpkZWYgbWFpbigpOgogICAgYXBpX2tleSA9IG9z
LmVudmlyb24uZ2V0KCdHRU1JTklfQVBJX0tFWScpCiAgICBpZiBub3QgYXBpX2tleToKICAg
ICAgICBwcmludCgiRXJyb3I6IEdFTUlOSV9BUElfS0VZIG5vdCBzZXQiLCBmaWxlPXN5cy5z
dGRlcnIpCiAgICAgICAgc3lzLmV4aXQoMSkKICAgIAogICAgIyBNQ1Agc2VydmVyIGltcGxl
bWVudGF0aW9uIGhlcmUKICAgIHByaW50KCJZb3VUdWJlIFRyYW5zY3JpcHQgTUNQIFNlcnZl
ciBydW5uaW5nLi4uIikKCmlmIF9fbmFtZV9fID09ICJfX21haW5fXyI6CiAgICBtYWluKCkK
EOF

# Cross-platform base64 decode - FIXED
decode_base64() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses -D flag
        echo "$1" | base64 -D
    else
        # Linux uses -d flag
        echo "$1" | base64 -d
    fi
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
    
    # Check for base64
    if ! command -v base64 &> /dev/null; then
        missing_deps+=("base64")
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
        
        if [[ " ${missing_deps[@]} " =~ " base64 " ]]; then
            echo "  base64:"
            echo "    Usually pre-installed, part of coreutils"
            echo "    macOS: brew install coreutils"
            echo "    Ubuntu/Debian: sudo apt-get install coreutils"
        fi
        
        exit 1
    fi
}

# Extract embedded server with validation - IMPROVED
extract_server() {
    local server_name="$1"
    local server_path="$SERVERS_DIR/$server_name.py"
    
    mkdir -p "$SERVERS_DIR"
    
    # Decode and save server script
    if ! decode_base64 "$EMBEDDED_SERVER_BASE64" > "$server_path"; then
        log_error "Failed to decode embedded server"
        exit 1
    fi
    
    chmod +x "$server_path"
    
    # Validate the extracted script
    local python_cmd
    python_cmd=$(detect_python)
    if ! "$python_cmd" -m py_compile "$server_path" 2>/dev/null; then
        log_error "Extracted server script has syntax errors"
        rm -f "$server_path"
        exit 1
    fi
    
    echo "$server_path"
}

# Detect Python command and version - IMPROVED CONSISTENCY
detect_python() {
    local python_cmd=""
    
    # Try python3 first, then python
    for cmd in python3 python; do
        if command -v "$cmd" &> /dev/null; then
            if "$cmd" -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" 2>/dev/null; then
                python_cmd="$cmd"
                break
            fi
        fi
    done
    
    if [ -z "$python_cmd" ]; then
        log_error "Python 3 is required but not found"
        exit 1
    fi
    
    local python_version
    python_version=$("$python_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
    log_info "Found Python: $python_cmd (version $python_version)"
    echo "$python_cmd"
}

# Client detection with proper array handling - IMPROVED CONSISTENCY
detect_clients() {
    local -a detected_clients=()
    
    # Check for Gemini CLI
    if [ -d "$HOME/.gemini" ]; then
        detected_clients+=("gemini")
    fi
    
    # Check for Claude Code
    if command -v claude &> /dev/null; then
        detected_clients+=("claude")
    fi
    
    # Check for Windsurf - ALIGNED WITH WINDOWS
    if [ -d "$HOME/.codeium/windsurf" ] || \
       [ -d "$HOME/Library/Application Support/Windsurf" ] || \
       [ -d "$HOME/.config/Windsurf" ]; then
        detected_clients+=("windsurf")
    fi
    
    # Check for Cursor
    if [ -d "$HOME/.cursor" ]; then
        detected_clients+=("cursor")
    fi
    
    # Return array properly
    if [ ${#detected_clients[@]} -eq 0 ]; then
        return 1
    else
        printf '%s\n' "${detected_clients[@]}"
        return 0
    fi
}

# Get or request API key with validation
get_or_request_key() {
    local key_name="$1"
    local prompt="$2"
    
    # Ensure installer directory exists
    mkdir -p "$INSTALLER_DIR"
    
    # Check if key already exists
    if [ -f "$KEYS_FILE" ]; then
        local existing_key
        existing_key=$(jq -r ".$key_name // empty" "$KEYS_FILE" 2>/dev/null || echo "")
        if [ -n "$existing_key" ]; then
            echo "$existing_key"
            return
        fi
    fi
    
    # Request key from user
    echo "$prompt" >&2
    read -r -p "Enter $key_name: " key_value
    
    # Validate key is not empty
    if [ -z "$key_value" ]; then
        log_error "API key cannot be empty"
        exit 1
    fi
    
    # Store key using atomic operation
    local temp_file
    temp_file=$(mktemp)
    
    if [ -f "$KEYS_FILE" ]; then
        jq --arg key "$key_name" --arg value "$key_value" '
            .[$key] = $value
        ' "$KEYS_FILE" > "$temp_file"
    else
        jq -n --arg key "$key_name" --arg value "$key_value" '
            {($key): $value}
        ' > "$temp_file"
    fi
    
    # Move atomically and set permissions
    mv "$temp_file" "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"
    
    echo "$key_value"
}

# Install for JSON-based clients with atomic updates
install_json_client() {
    local client="$1"
    local config_path="$2"
    local server_name="$3"
    local server_config="$4"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$config_path")"
    
    # Use atomic file operations
    local temp_file
    temp_file=$(mktemp)
    
    # Create or update configuration
    if [ -f "$config_path" ]; then
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
    
    # Validate JSON before moving
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$config_path"
        log_info "Installed $server_name for $client"
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
    
    # Build command array
    local -a cmd=("claude" "mcp" "add" "$server_name" "-s" "user")
    
    if [ -n "$command" ]; then
        cmd+=("$command")
        
        # Add args if provided
        if [ -n "$args_json" ] && [ "$args_json" != "[]" ]; then
            # Parse JSON array safely
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
    
    # Execute command
    if eval "$env_cmd" "${cmd[@]}" 2>/dev/null; then
        log_info "Installed $server_name for Claude Code"
        return 0
    else
        log_error "Failed to install for Claude Code"
        log_warn "You may need to install manually using: claude mcp add"
        return 1
    fi
}

# Main installation function
install_server() {
    local server_type="${1:-youtube}"
    
    case "$server_type" in
        "youtube")
            install_youtube_server
            ;;
        *)
            log_error "Unknown server type: $server_type"
            echo "Usage: $0 [youtube]"
            exit 1
            ;;
    esac
}

# YouTube server installation
install_youtube_server() {
    log_info "YouTube Transcript MCP Server Installer v$INSTALLER_VERSION"
    echo "================================================"
    
    # Get Gemini API key (only once)
    local gemini_key
    gemini_key=$(get_or_request_key "GEMINI_API_KEY" \
        "This server requires a Gemini API key for transcript processing.
Get your key from: https://makersuite.google.com/app/apikey")
    
    # Detect Python
    local python_cmd
    python_cmd=$(detect_python)
    
    # Extract embedded server
    log_info "Extracting server files..."
    local server_script
    server_script=$(extract_server "youtube_transcript_server")
    
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
        echo "  - Claude Code"
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
                    --arg cmd "$python_cmd" \
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
                
            "claude")
                if install_claude "youtube-transcript" "$python_cmd" "[\"$server_script\"]" "{\"GEMINI_API_KEY\": \"$gemini_key\"}"; then
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
                    --arg cmd "$python_cmd" \
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
                    --arg cmd "$python_cmd" \
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
    create_test_script "$python_cmd" "$server_script" "$gemini_key"
    
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

# Create test script with security warning - IMPROVED
create_test_script() {
    local python_cmd="$1"
    local server_script="$2"
    local api_key="$3"
    
    local test_script="$INSTALLER_DIR/test-server.sh"
    
    cat > "$test_script" << EOF
#!/bin/bash
# YouTube Transcript MCP Server Test Script
# Auto-generated by MCP Universal Installer
#
# WARNING: This script contains your API key in plain text
# Do not share or commit this file to version control

export GEMINI_API_KEY="$api_key"
echo "Testing YouTube Transcript MCP Server..."
echo "Press Ctrl+C to stop"
echo ""
echo "WARNING: This script contains your API key"
echo "Do not share this file"
echo ""
exec "$python_cmd" "$server_script"
EOF
    
    chmod +x "$test_script"
}

# Main entry point
main() {
    check_dependencies
    install_server "$@"
}

# Run main function
main "$@"
```

### 3. PowerShell Installer (`install.ps1`)

```powershell
# Universal MCP Server Installer for Windows
# Self-contained installer with embedded server
# Requires PowerShell 5.0 or higher

#Requires -Version 5.0

param(
    [string]$ServerType = "youtube"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Configuration
$INSTALLER_VERSION = "2.0.0"
$INSTALLER_DIR = "$env:LOCALAPPDATA\.mcp-installer"
$KEYS_FILE = "$INSTALLER_DIR\keys.json"
$SERVERS_DIR = "$INSTALLER_DIR\servers"

# Logging functions
function Write-Success { 
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $args 
}

function Write-Error { 
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $args 
}

function Write-Warning { 
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $args 
}

# Embedded MCP server script (base64 encoded)
$EMBEDDED_SERVER_BASE64 = @'
IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwojIFlvdVR1YmUgVHJhbnNjcmlwdCBNQ1AgU2VydmVy
CiMgRXhhbXBsZSBzZXJ2ZXIgLSByZXBsYWNlIHdpdGggYWN0dWFsIGNvZGUKCmltcG9ydCBv
cwppbXBvcnQganNvbgppbXBvcnQgc3lzCgpkZWYgbWFpbigpOgogICAgYXBpX2tleSA9IG9z
LmVudmlyb24uZ2V0KCdHRU1JTklfQVBJX0tFWScpCiAgICBpZiBub3QgYXBpX2tleToKICAg
ICAgICBwcmludCgiRXJyb3I6IEdFTUlOSV9BUElfS0VZIG5vdCBzZXQiLCBmaWxlPXN5cy5z
dGRlcnIpCiAgICAgICAgc3lzLmV4aXQoMSkKICAgIAogICAgIyBNQ1Agc2VydmVyIGltcGxl
bWVudGF0aW9uIGhlcmUKICAgIHByaW50KCJZb3VUdWJlIFRyYW5zY3JpcHQgTUNQIFNlcnZl
ciBydW5uaW5nLi4uIikKCmlmIF9fbmFtZV9fID09ICJfX21haW5fXyI6CiAgICBtYWluKCkK
'@

# Initialize installer directory
function Initialize-InstallerDirectory {
    if (-not (Test-Path $INSTALLER_DIR)) {
        New-Item -ItemType Directory -Path $INSTALLER_DIR -Force | Out-Null
    }
    if (-not (Test-Path $SERVERS_DIR)) {
        New-Item -ItemType Directory -Path $SERVERS_DIR -Force | Out-Null
    }
}

# Extract embedded server with validation - IMPROVED
function Extract-Server {
    param(
        [string]$ServerName
    )
    
    $serverPath = Join-Path $SERVERS_DIR "$ServerName.py"
    
    # Decode base64 and save
    try {
        $serverBytes = [Convert]::FromBase64String($EMBEDDED_SERVER_BASE64)
        $serverContent = [System.Text.Encoding]::UTF8.GetString($serverBytes)
        Set-Content -Path $serverPath -Value $serverContent -Encoding UTF8 -Force
    } catch {
        Write-Error "Failed to decode embedded server: $_"
        exit 1
    }
    
    # Validate the extracted script
    $pythonCmd = Get-PythonCommand
    $validateResult = & $pythonCmd -m py_compile $serverPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Extracted server script has syntax errors"
        Remove-Item $serverPath -Force
        exit 1
    }
    
    return $serverPath
}

# Detect Python command and version - IMPROVED CONSISTENCY
function Get-PythonCommand {
    $pythonCmd = $null
    $pythonVersion = $null
    
    # Try python3 first, then python
    $candidates = @("python3", "python")
    foreach ($cmd in $candidates) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            $result = & $cmd -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $pythonCmd = $cmd
                $pythonVersion = & $cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
                break
            }
        } catch {
            # Continue to next candidate
        }
    }
    
    if (-not $pythonCmd) {
        Write-Error "Python 3 is required but not found"
        Write-Host "Please install Python 3 from https://www.python.org/downloads/"
        exit 1
    }
    
    Write-Success "Found Python: $pythonCmd (version $pythonVersion)"
    return $pythonCmd
}

# Client detection - IMPROVED CONSISTENCY
function Get-InstalledClients {
    $clients = @()
    
    # Check for Gemini CLI
    if (Test-Path "$env:USERPROFILE\.gemini") {
        $clients += "gemini"
    }
    
    # Check for Claude Code
    try {
        $null = Get-Command claude -ErrorAction Stop
        $clients += "claude"
    } catch {}
    
    # Check for Windsurf - ALIGNED WITH BASH
    if ((Test-Path "$env:APPDATA\Codeium\Windsurf") -or 
        (Test-Path "$env:LOCALAPPDATA\Windsurf") -or
        (Test-Path "$env:USERPROFILE\.config\Windsurf")) {
        $clients += "windsurf"
    }
    
    # Check for Cursor
    if (Test-Path "$env:USERPROFILE\.cursor") {
        $clients += "cursor"
    }
    
    return $clients
}

# Get or request API key
function Get-OrRequestKey {
    param(
        [string]$KeyName,
        [string]$Prompt
    )
    
    Initialize-InstallerDirectory
    
    # Check if key already exists
    if (Test-Path $KEYS_FILE) {
        try {
            $keys = Get-Content $KEYS_FILE | ConvertFrom-Json
            if ($keys.$KeyName) {
                return $keys.$KeyName
            }
        } catch {
            # Continue to request new key
        }
    }
    
    # Request key from user
    Write-Host $Prompt
    $keyValue = Read-Host "Enter $KeyName"
    
    # Validate key is not empty
    if ([string]::IsNullOrWhiteSpace($keyValue)) {
        Write-Error "API key cannot be empty"
        exit 1
    }
    
    # Store key
    $keys = if (Test-Path $KEYS_FILE) {
        try {
            Get-Content $KEYS_FILE -Raw | ConvertFrom-Json
        } catch {
            @{}
        }
    } else {
        @{}
    }
    
    # Ensure keys is a proper object
    if ($keys -isnot [PSCustomObject]) {
        $keys = [PSCustomObject]@{}
    }
    
    $keys | Add-Member -NotePropertyName $KeyName -NotePropertyValue $keyValue -Force
    $keys | ConvertTo-Json | Set-Content $KEYS_FILE -Encoding UTF8
    
    # Set file permissions (restrict to current user)
    $acl = Get-Acl $KEYS_FILE
    $acl.SetAccessRuleProtection($true, $false)
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl",
        "Allow"
    )
    $acl.SetAccessRule($accessRule)
    Set-Acl $KEYS_FILE $acl
    
    return $keyValue
}

# Install for JSON-based clients
function Install-JsonClient {
    param(
        [string]$Client,
        [string]$ConfigPath,
        [string]$ServerName,
        [hashtable]$ServerConfig
    )
    
    # Ensure directory exists
    $configDir = Split-Path $ConfigPath -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    # Load or create configuration
    $config = if (Test-Path $ConfigPath) {
        try {
            Get-Content $ConfigPath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Existing config is invalid, creating new one"
            [PSCustomObject]@{ mcpServers = @{} }
        }
    } else {
        [PSCustomObject]@{ mcpServers = @{} }
    }
    
    # Ensure mcpServers property exists and is the right type
    if (-not $config.mcpServers) {
        $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    
    # Add server configuration
    $config.mcpServers | Add-Member -NotePropertyName $ServerName -NotePropertyValue $ServerConfig -Force
    
    # Save configuration with proper formatting
    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
        Write-Success "Installed $ServerName for $Client"
        return $true
    } catch {
        Write-Error "Failed to save configuration for $Client`: $_"
        return $false
    }
}

# Install for Claude Code using CLI - FIXED
function Install-Claude {
    param(
        [string]$ServerName,
        [string]$Command,
        [string[]]$Args,
        [hashtable]$Env
    )
    
    $cmd = @("claude", "mcp", "add", $ServerName, "-s", "user")
    
    if ($Command) {
        $cmd += $Command
        if ($Args) {
            $cmd += $Args
        }
    }
    
    # Better approach for environment variables
    $originalEnv = @{}
    foreach ($key in $Env.Keys) {
        $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, $Env[$key], "Process")
    }
    
    try {
        # Run claude command directly
        & claude @cmd[1..($cmd.Length-1)] 2>&1 | Out-Null
        $success = $LASTEXITCODE -eq 0
        
        if ($success) {
            Write-Success "Installed $ServerName for Claude Code"
            return $true
        } else {
            Write-Error "Claude command failed with exit code: $LASTEXITCODE"
            return $false
        }
    } catch {
        Write-Error "Failed to install for Claude Code: $_"
        Write-Warning "You may need to install manually using: claude mcp add"
        return $false
    } finally {
        # Restore original environment
        foreach ($key in $Env.Keys) {
            if ($null -ne $originalEnv[$key]) {
                [Environment]::SetEnvironmentVariable($key, $originalEnv[$key], "Process")
            } else {
                [Environment]::SetEnvironmentVariable($key, $null, "Process")
            }
        }
    }
}

# YouTube server installation
function Install-YouTubeServer {
    Write-Success "YouTube Transcript MCP Server Installer v$INSTALLER_VERSION"
    Write-Host ("=" * 50)
    
    # Get Gemini API key (only once)
    $geminiKey = Get-OrRequestKey -KeyName "GEMINI_API_KEY" -Prompt @"
This server requires a Gemini API key for transcript processing.
Get your key from: https://makersuite.google.com/app/apikey
"@
    
    # Detect Python
    $pythonCmd = Get-PythonCommand
    
    # Extract embedded server
    Write-Success "Extracting server files..."
    Initialize-InstallerDirectory
    $serverScript = Extract-Server -ServerName "youtube_transcript_server"
    
    # Detect installed clients
    Write-Success "Detecting installed AI assistants..."
    $clients = Get-InstalledClients
    
    if ($clients.Count -eq 0) {
        Write-Error "No supported AI assistants detected"
        Write-Host ""
        Write-Host "Supported clients:"
        Write-Host "  - Gemini CLI"
        Write-Host "  - Claude Code"  
        Write-Host "  - Windsurf"
        Write-Host "  - Cursor"
        exit 1
    }
    
    Write-Success "Found $($clients.Count) client(s): $($clients -join ', ')"
    
    # Install for each client
    $successCount = 0
    foreach ($client in $clients) {
        Write-Host ""
        Write-Success "Configuring $client..."
        
        $success = switch ($client) {
            "gemini" {
                $configPath = Join-Path $env:USERPROFILE ".gemini\settings.json"
                $serverConfig = @{
                    command = $pythonCmd
                    args = @($serverScript)
                    env = @{
                        GEMINI_API_KEY = $geminiKey  # FIXED - use actual key
                    }
                }
                Install-JsonClient -Client $client -ConfigPath $configPath `
                    -ServerName "youtube-transcript" -ServerConfig $serverConfig
            }
            
            "claude" {
                Install-Claude -ServerName "youtube-transcript" -Command $pythonCmd `
                    -Args @($serverScript) -Env @{ GEMINI_API_KEY = $geminiKey }
            }
            
            "windsurf" {
                $configPath = if (Test-Path "$env:LOCALAPPDATA\Windsurf") {
                    Join-Path $env:LOCALAPPDATA "Windsurf\mcp_config.json"
                } elseif (Test-Path "$env:USERPROFILE\.config\Windsurf") {
                    Join-Path $env:USERPROFILE ".config\Windsurf\mcp_config.json"
                } else {
                    Join-Path $env:APPDATA "Codeium\Windsurf\mcp_config.json"
                }
                
                $serverConfig = @{
                    command = $pythonCmd
                    args = @($serverScript)
                    env = @{
                        GEMINI_API_KEY = $geminiKey
                    }
                }
                Install-JsonClient -Client $client -ConfigPath $configPath `
                    -ServerName "youtube-transcript" -ServerConfig $serverConfig
            }
            
            "cursor" {
                $configPath = Join-Path $env:USERPROFILE ".cursor\mcp.json"
                $serverConfig = @{
                    command = $pythonCmd
                    args = @($serverScript)
                    env = @{
                        GEMINI_API_KEY = $geminiKey
                    }
                }
                Install-JsonClient -Client $client -ConfigPath $configPath `
                    -ServerName "youtube-transcript" -ServerConfig $serverConfig
            }
        }
        
        if ($success) {
            $successCount++
        }
    }
    
    # Create test script
    New-TestScript -PythonCmd $pythonCmd -ServerScript $serverScript -ApiKey $geminiKey
    
    Write-Host ""
    if ($successCount -gt 0) {
        Write-Success "Installation complete! ($successCount/$($clients.Count) clients configured)"
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "1. Restart any running AI assistant applications"
        Write-Host "2. The server will be available as 'youtube-transcript' in configured clients"
        Write-Host "3. Test the server with: $INSTALLER_DIR\test-server.ps1"
        
        if ($successCount -lt $clients.Count) {
            Write-Host ""
            Write-Warning "Some clients failed to configure. Check the errors above."
        }
    } else {
        Write-Error "Installation failed for all clients"
        exit 1
    }
}

# Create test script with security warning - IMPROVED
function New-TestScript {
    param(
        [string]$PythonCmd,
        [string]$ServerScript,
        [string]$ApiKey
    )
    
    $testScript = Join-Path $INSTALLER_DIR "test-server.ps1"
    
    @"
# YouTube Transcript MCP Server Test Script
# Auto-generated by MCP Universal Installer
#
# WARNING: This script contains your API key in plain text
# Do not share or commit this file to version control

`$env:GEMINI_API_KEY = "$ApiKey"
Write-Host "Testing YouTube Transcript MCP Server..."
Write-Host "Press Ctrl+C to stop"
Write-Host ""
Write-Host "WARNING: This script contains your API key" -ForegroundColor Yellow
Write-Host "Do not share this file" -ForegroundColor Yellow
Write-Host ""
& "$PythonCmd" "$ServerScript"
"@ | Set-Content $testScript -Encoding UTF8
    
    # Also create a batch file for easier execution
    $testBatch = Join-Path $INSTALLER_DIR "test-server.cmd"
    
    @"
@echo off
REM YouTube Transcript MCP Server Test Script
REM WARNING: Contains API key - do not share
powershell -ExecutionPolicy Bypass -File "$testScript"
"@ | Set-Content $testBatch -Encoding UTF8
}

# Main entry point
switch ($ServerType) {
    "youtube" {
        Install-YouTubeServer
    }
    default {
        Write-Host "Usage: .\install.ps1 [-ServerType youtube]"
        exit 1
    }
}
```

## Key Fixes Applied

1. **PowerShell Variable Name Bug**: Fixed line 809 - changed `$claudeArgs` to `$cmd`
2. **Gemini API Key Bug**: Fixed line 879 - now uses actual `$geminiKey` variable instead of placeholder
3. **Base64 Cross-Platform**: Added `decode_base64` function that handles macOS (-D) vs Linux (-d) flags
4. **PowerShell Version Check**: Fixed batch file to properly parse PowerShell version
5. **Claude Environment Variables**: Improved handling using process-level environment variables
6. **Python Detection**: Unified approach across platforms using consistent logic
7. **Client Path Detection**: Aligned Windsurf detection paths between platforms
8. **Security Warnings**: Added clear warnings to test scripts about API key exposure
9. **Server Validation**: Added Python syntax validation after extracting embedded server

## Additional Improvements

- Added dependency check for `base64` command
- Better error messages throughout
- Consistent logging format
- Proper error handling for base64 decode failures
- Validation of extracted server script syntax
- More robust JSON handling in PowerShell

The fixed version maintains all the original functionality while addressing the identified bugs and improving cross-platform consistency.