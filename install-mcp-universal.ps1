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