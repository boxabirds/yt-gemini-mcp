# Git-Free MCP Server Installation Plan

## Overview

This document outlines a bootstrap approach that allows users to install the MCP server without git by downloading only the necessary files directly from the repository. The installer will be truly self-contained and minimal.

## Architecture

### Core Concept

1. **Single Bootstrap Script**: One small script that users can download and run
2. **Direct File Downloads**: Uses curl/wget (Unix) or Invoke-WebRequest (Windows)
3. **Minimal Dependencies**: Only requires standard HTTP tools and shell
4. **Self-Contained Server**: Downloads and embeds the MCP server directly

### Distribution Methods

```
User runs one of:
1. curl -sSL https://your-domain.com/bootstrap.sh | bash
2. iwr -useb https://your-domain.com/bootstrap.ps1 | iex
3. Download and run bootstrap script manually
```

## Implementation

### 1. Universal Bootstrap Script (`bootstrap.sh`)

```bash
#!/bin/bash
# MCP Server Bootstrap Installer
# Downloads and installs YouTube Transcript MCP Server without git

set -euo pipefail

# Configuration
REPO_BASE="https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main"
INSTALLER_VERSION="1.0.0"
TEMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Detect downloader
get_downloader() {
    if command -v curl &> /dev/null; then
        echo "curl -sSL"
    elif command -v wget &> /dev/null; then
        echo "wget -qO-"
    else
        log_error "Neither curl nor wget found. Please install one."
        exit 1
    fi
}

# Download file
download_file() {
    local url="$1"
    local output="$2"
    local downloader=$(get_downloader)
    
    if [[ "$downloader" == "curl"* ]]; then
        curl -sSL "$url" -o "$output"
    else
        wget -qO "$output" "$url"
    fi
}

# Main installation
main() {
    log_info "YouTube Transcript MCP Server Bootstrap Installer v$INSTALLER_VERSION"
    echo "============================================================"
    
    # Check dependencies
    if ! command -v jq &> /dev/null; then
        log_warn "jq is required but not installed"
        echo "Install jq:"
        echo "  macOS: brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  RHEL/CentOS: sudo yum install jq"
        exit 1
    fi
    
    # Detect Python
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
    
    log_info "Downloading installer files..."
    
    # Download the main installer script
    local installer_path="$TEMP_DIR/install.sh"
    download_file "$REPO_BASE/installers/install-native.sh" "$installer_path"
    chmod +x "$installer_path"
    
    # Download the MCP server script
    local server_path="$TEMP_DIR/youtube_transcript_server.py"
    download_file "$REPO_BASE/servers/youtube_transcript_server_fastmcp.py" "$server_path"
    
    # Create a temporary installer with embedded server
    log_info "Creating self-contained installer..."
    create_embedded_installer "$installer_path" "$server_path"
    
    # Run the installer
    log_info "Running installer..."
    bash "$TEMP_DIR/install-embedded.sh"
    
    log_info "Bootstrap complete!"
}

# Create installer with embedded server
create_embedded_installer() {
    local installer_template="$1"
    local server_file="$2"
    local output="$TEMP_DIR/install-embedded.sh"
    
    # Encode server as base64
    local server_base64
    if [[ "$OSTYPE" == "darwin"* ]]; then
        server_base64=$(base64 < "$server_file")
    else
        server_base64=$(base64 -w0 < "$server_file")
    fi
    
    # Create new installer with embedded server
    cat > "$output" << 'INSTALLER_START'
#!/bin/bash
# Auto-generated MCP installer with embedded server

set -euo pipefail

# Embedded server (base64)
EMBEDDED_SERVER_BASE64='
INSTALLER_START
    
    echo "$server_base64" >> "$output"
    
    cat >> "$output" << 'INSTALLER_END'
'

# Rest of installer code
INSTALLER_END
    
    # Append the main installer logic (minus the download parts)
    sed -n '/^# Main installation function/,$p' "$installer_template" >> "$output"
    
    chmod +x "$output"
}

# Run main
main "$@"
```

### 2. Windows Bootstrap Script (`bootstrap.ps1`)

```powershell
# MCP Server Bootstrap Installer for Windows
# Downloads and installs YouTube Transcript MCP Server without git

#Requires -Version 5.0

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Configuration
$REPO_BASE = "https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main"
$INSTALLER_VERSION = "1.0.0"
$TEMP_DIR = New-TemporaryFile | %{ Remove-Item $_; New-Item -ItemType Directory -Path $_ }

# Logging
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

# Cleanup
$CleanupBlock = {
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Recurse -Force $TEMP_DIR -ErrorAction SilentlyContinue
    }
}
Register-EngineEvent PowerShell.Exiting -Action $CleanupBlock | Out-Null

# Download file
function Download-File {
    param(
        [string]$Url,
        [string]$Output
    )
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing
    } catch {
        Write-Error "Failed to download $Url : $_"
        exit 1
    }
}

# Main
function Main {
    Write-Success "YouTube Transcript MCP Server Bootstrap Installer v$INSTALLER_VERSION"
    Write-Host ("=" * 60)
    
    # Detect Python
    $pythonCmd = $null
    foreach ($cmd in @("python3", "python")) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            $result = & $cmd -c "import sys; sys.exit(0 if sys.version_info.major >= 3 else 1)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $pythonCmd = $cmd
                break
            }
        } catch {}
    }
    
    if (-not $pythonCmd) {
        Write-Error "Python 3 is required but not found"
        Write-Host "Download from: https://www.python.org/downloads/"
        exit 1
    }
    
    Write-Success "Downloading installer files..."
    
    # Download main installer
    $installerPath = Join-Path $TEMP_DIR "install.ps1"
    Download-File -Url "$REPO_BASE/installers/install-native.ps1" -Output $installerPath
    
    # Download MCP server
    $serverPath = Join-Path $TEMP_DIR "youtube_transcript_server.py"
    Download-File -Url "$REPO_BASE/servers/youtube_transcript_server_fastmcp.py" -Output $serverPath
    
    # Create embedded installer
    Write-Success "Creating self-contained installer..."
    Create-EmbeddedInstaller -InstallerPath $installerPath -ServerPath $serverPath
    
    # Run installer
    Write-Success "Running installer..."
    & powershell -ExecutionPolicy Bypass -File (Join-Path $TEMP_DIR "install-embedded.ps1")
    
    Write-Success "Bootstrap complete!"
}

# Create embedded installer
function Create-EmbeddedInstaller {
    param(
        [string]$InstallerPath,
        [string]$ServerPath
    )
    
    $outputPath = Join-Path $TEMP_DIR "install-embedded.ps1"
    
    # Read and encode server
    $serverContent = Get-Content $ServerPath -Raw
    $serverBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($serverContent))
    
    # Create embedded installer
    @"
# Auto-generated MCP installer with embedded server
#Requires -Version 5.0

`$ErrorActionPreference = "Stop"

# Embedded server (base64)
`$EMBEDDED_SERVER_BASE64 = @'
$serverBase64
'@

# Rest of installer code follows...
"@ | Set-Content $outputPath
    
    # Append installer logic (excluding download parts)
    Get-Content $InstallerPath | Select-Object -Skip 50 | Add-Content $outputPath
}

# Run
Main
```

### 3. Minimal One-Liner Bootstraps

#### For Unix/Linux/macOS:
```bash
# Using curl
curl -sSL https://your-domain.com/bootstrap.sh | bash

# Using wget
wget -qO- https://your-domain.com/bootstrap.sh | bash

# With custom domain
curl -sSL https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main/bootstrap.sh | bash
```

#### For Windows (PowerShell):
```powershell
# Short version
iwr -useb https://your-domain.com/bootstrap.ps1 | iex

# Full version
Invoke-WebRequest -UseBasicParsing https://your-domain.com/bootstrap.ps1 | Invoke-Expression

# From GitHub
iwr -useb https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main/bootstrap.ps1 | iex
```

### 4. Ultra-Minimal Bootstrap (`bootstrap-mini.sh`)

For maximum compatibility and minimal size:

```bash
#!/bin/sh
# Ultra-minimal MCP bootstrap - works with basic POSIX shell

# Download and run full installer
if command -v curl >/dev/null 2>&1; then
    curl -sSL https://your-domain.com/install-full.sh | bash
elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://your-domain.com/install-full.sh | bash
else
    echo "Error: curl or wget required" >&2
    exit 1
fi
```

### 5. CDN-Hosted Installation Page

Create a simple HTML page for users who prefer clicking:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Install YouTube Transcript MCP Server</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
               max-width: 800px; margin: 0 auto; padding: 20px; }
        .install-box { background: #f5f5f5; padding: 20px; border-radius: 8px; 
                      margin: 20px 0; font-family: 'Monaco', 'Consolas', monospace; }
        .platform { margin: 20px 0; }
        button { background: #0066cc; color: white; border: none; 
                padding: 10px 20px; border-radius: 4px; cursor: pointer; }
        button:hover { background: #0052a3; }
    </style>
</head>
<body>
    <h1>YouTube Transcript MCP Server Installer</h1>
    
    <div class="platform">
        <h2>macOS / Linux</h2>
        <div class="install-box">
            curl -sSL https://install.your-domain.com/mcp | bash
        </div>
        <button onclick="copyToClipboard('curl -sSL https://install.your-domain.com/mcp | bash')">
            Copy Command
        </button>
    </div>
    
    <div class="platform">
        <h2>Windows (PowerShell)</h2>
        <div class="install-box">
            iwr -useb https://install.your-domain.com/mcp.ps1 | iex
        </div>
        <button onclick="copyToClipboard('iwr -useb https://install.your-domain.com/mcp.ps1 | iex')">
            Copy Command
        </button>
    </div>
    
    <script>
        function copyToClipboard(text) {
            navigator.clipboard.writeText(text).then(() => {
                alert('Command copied to clipboard!');
            });
        }
    </script>
</body>
</html>
```

## File Download Strategy

### Required Files Only

The bootstrap script downloads only what's needed:

1. **Server Script**: `youtube_transcript_server_fastmcp.py` (~10KB)
2. **Configuration Template**: Embedded in bootstrap script
3. **No Extra Files**: No README, tests, or documentation

### Download Sources (in order of preference)

1. **CDN**: `https://cdn.your-domain.com/mcp/files/`
2. **GitHub Raw**: `https://raw.githubusercontent.com/user/repo/main/`
3. **GitLab Raw**: `https://gitlab.com/user/repo/-/raw/main/`
4. **Direct Server**: `https://your-domain.com/mcp/files/`

### Fallback Chain

```bash
# Try multiple sources
SOURCES=(
    "https://cdn.your-domain.com/mcp"
    "https://raw.githubusercontent.com/user/repo/main"
    "https://your-backup-cdn.com/mcp"
)

for source in "${SOURCES[@]}"; do
    if download_file "$source/server.py" "$output"; then
        break
    fi
done
```

## Security Considerations

### 1. HTTPS Only
- All downloads must use HTTPS
- Reject any HTTP redirects

### 2. Checksum Verification
```bash
# Embedded checksums
declare -A CHECKSUMS=(
    ["server.py"]="sha256:abcd1234..."
    ["config.json"]="sha256:efgh5678..."
)

verify_checksum() {
    local file="$1"
    local expected="${CHECKSUMS[$(basename "$file")]}"
    local actual=$(sha256sum "$file" | cut -d' ' -f1)
    
    if [ "$actual" != "$expected" ]; then
        log_error "Checksum mismatch for $file"
        exit 1
    fi
}
```

### 3. Minimal Permissions
- Scripts run with user permissions only
- No sudo/admin required
- Files created with restrictive permissions

## Advantages Over Git-Based Install

1. **No Git Required**: Works on minimal systems
2. **Faster**: Downloads only required files (~20KB total)
3. **Simpler**: One command, no repository management
4. **Portable**: Works behind firewalls that block git
5. **Lightweight**: No git history or extra files

## Implementation Timeline

### Phase 1: Basic Bootstrap (Week 1)
- Create bootstrap scripts for both platforms
- Test direct file downloads
- Implement embedded server approach

### Phase 2: CDN Setup (Week 2)
- Set up CDN or static hosting
- Configure proper CORS headers
- Implement fallback sources

### Phase 3: Security & Polish (Week 3)
- Add checksum verification
- Create installation webpage
- Test on various platforms and networks

### Phase 4: Launch (Week 4)
- Deploy to production CDN
- Update documentation
- Monitor usage and errors

## Testing Strategy

### Network Conditions
- Test with slow connections
- Test with corporate proxies
- Test with GitHub rate limits

### Platform Testing
- macOS 11+ (Intel and Apple Silicon)
- Ubuntu 20.04+
- Windows 10/11
- WSL2

### Failure Scenarios
- Missing dependencies
- Network timeouts
- Partial downloads
- Corrupted files

## Cost Estimation

### CDN Hosting (Monthly)
- Storage: ~1MB * $0.023/GB = ~$0.00
- Bandwidth: 10,000 installs * 50KB = 500MB * $0.085/GB = ~$0.04
- **Total: < $1/month**

### Alternative: GitHub Pages
- Cost: Free
- Limitations: 100GB bandwidth/month
- Perfect for open source projects

## Conclusion

The git-free bootstrap approach provides:
- **Minimal Dependencies**: Only requires curl/wget or PowerShell
- **Fast Installation**: ~50KB total download
- **Wide Compatibility**: Works on restricted networks
- **Simple Distribution**: One-line installers
- **Low Maintenance**: Self-contained scripts

This approach significantly reduces barriers to installation while maintaining security and reliability.