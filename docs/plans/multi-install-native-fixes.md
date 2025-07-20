# Multi-Install Native Script Fixes

## Critical Bug Fixes

### 1. PowerShell Variable Name Bug (Line 809)
```powershell
# WRONG:
$process = Start-Process -FilePath "claude" `
    -ArgumentList $claudeArgs `  # <-- Variable doesn't exist

# CORRECT:
$process = Start-Process -FilePath "claude" `
    -ArgumentList $cmd `         # <-- Use correct variable
```

### 2. Gemini API Key Bug (Line 879)
```powershell
# WRONG:
env = @{
    GEMINI_API_KEY = "$GEMINI_API_KEY"  # <-- Literal string
}

# CORRECT:
env = @{
    GEMINI_API_KEY = $geminiKey         # <-- Use actual variable
}
```

### 3. Base64 Decode Cross-Platform Fix (Line 146)
```bash
# Add platform detection for base64 command
decode_base64() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses -D flag
        echo "$1" | base64 -D
    else
        # Linux uses -d flag
        echo "$1" | base64 -d
    fi
}

# Then use:
decode_base64 "$EMBEDDED_SERVER_BASE64" > "$server_path"
```

### 4. PowerShell Version Check Fix (Line 51)
```batch
REM WRONG:
for /f "tokens=2 delims=." %%i in ('powershell -Command "$PSVersionTable.PSVersion.Major"') do set PS_MAJOR=%%i

REM CORRECT:
for /f %%i in ('powershell -Command "$PSVersionTable.PSVersion.Major"') do set PS_MAJOR=%%i
```

### 5. Claude PowerShell Environment Fix
```powershell
# Current approach with Start-Process doesn't properly pass environment
# Better approach:
$originalEnv = @{}
foreach ($key in $Env.Keys) {
    $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key)
    [Environment]::SetEnvironmentVariable($key, $Env[$key])
}

try {
    & claude @cmd
    $success = $LASTEXITCODE -eq 0
} finally {
    # Restore original environment
    foreach ($key in $Env.Keys) {
        if ($originalEnv[$key]) {
            [Environment]::SetEnvironmentVariable($key, $originalEnv[$key])
        } else {
            [Environment]::SetEnvironmentVariable($key, $null)
        }
    }
}
```

## Consistency Improvements

### 1. Unified Python Detection
Create consistent Python detection across platforms:

**Bash version:**
```bash
detect_python() {
    for cmd in python3 python; do
        if command -v "$cmd" &> /dev/null; then
            if "$cmd" -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" 2>/dev/null; then
                echo "$cmd"
                return 0
            fi
        fi
    done
    return 1
}
```

**PowerShell version:**
```powershell
function Get-PythonCommand {
    $candidates = @("python3", "python")
    foreach ($cmd in $candidates) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            $result = & $cmd -c "import sys; sys.exit(0 if sys.version_info.major == 3 else 1)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $cmd
            }
        } catch {}
    }
    return $null
}
```

### 2. Consistent Client Path Detection

Align the paths checked between platforms:

```bash
# Windsurf paths (Bash)
if [ -d "$HOME/.codeium/windsurf" ] || \
   [ -d "$HOME/Library/Application Support/Windsurf" ] || \
   [ -d "$HOME/.config/Windsurf" ]; then
    detected_clients+=("windsurf")
fi
```

```powershell
# Windsurf paths (PowerShell)
if ((Test-Path "$env:APPDATA\Codeium\Windsurf") -or 
    (Test-Path "$env:LOCALAPPDATA\Windsurf") -or
    (Test-Path "$env:USERPROFILE\.config\Windsurf")) {
    $clients += "windsurf"
}
```

## Security Improvements

### 1. API Key Warning in Test Scripts
Add warnings to test scripts:

```bash
cat > "$test_script" << EOF
#!/bin/bash
# YouTube Transcript MCP Server Test Script
# WARNING: This script contains your API key in plain text
# Do not share or commit this file

export GEMINI_API_KEY="$api_key"
echo "Testing YouTube Transcript MCP Server..."
echo "Press Ctrl+C to stop"
exec "$python_cmd" "$server_script"
EOF
```

### 2. Validate Extracted Server
Add validation after extracting embedded server:

```bash
# After extraction, validate the script
if ! "$python_cmd" -m py_compile "$server_path" 2>/dev/null; then
    log_error "Extracted server script has syntax errors"
    exit 1
fi
```

## Additional Recommendations

1. **Add rollback mechanism** for failed installations
2. **Log installation actions** for debugging
3. **Add --dry-run option** to preview changes
4. **Implement update detection** to avoid duplicate entries
5. **Add uninstall functionality**