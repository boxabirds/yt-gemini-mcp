# MCP Server Installation Guide for AI Coding Assistants

This document provides comprehensive research on programmatically installing MCP (Model Context Protocol) servers across major AI coding assistants: Gemini CLI, Claude Code, Windsurf, and Cursor.

## Table of Contents
- [Overview](#overview)
- [Gemini CLI](#gemini-cli)
- [Claude Code](#claude-code)
- [Windsurf](#windsurf)
- [Cursor](#cursor)
- [Cross-Platform Comparison](#cross-platform-comparison)
- [Programmatic Installation Strategies](#programmatic-installation-strategies)

## Overview

MCP (Model Context Protocol) is an open-source protocol that enables AI assistants to connect with external tools, services, and data sources through a standardized interface. Each AI coding assistant implements MCP support with slight variations in configuration and installation methods.

## Gemini CLI

### Configuration Locations
- **Global**: `~/.gemini/settings.json`
- **Project-level**: `.gemini/settings.json` (in project root)

### Configuration Format
```json
{
  "mcpServers": {
    "serverName": {
      "command": "path/to/server",
      "args": ["--arg1", "value1"],
      "env": {
        "API_KEY": "$MY_API_TOKEN"
      },
      "cwd": "./server-directory",
      "timeout": 30000,
      "trust": false
    }
  }
}
```

### Platform Differences
- Configuration paths are consistent across Windows, macOS, and Linux
- Requires Node.js 18+ (recommended 20+)
- Environment variables can be referenced with `$` prefix

### Programmatic Methods
Currently requires manual JSON file editing. Proposed future CLI commands (not yet implemented):
```bash
gemini mcp add --transport http <name> <url>
gemini mcp add --transport http secure-server https://api.example.com/mcp --header "Authorization: Bearer token"
```

### CLI Commands
```bash
/mcp                    # List configured servers and status
/mcp desc              # Show detailed descriptions
/mcp nodesc            # Hide descriptions
/mcp schema            # Show full JSON schema
```

## Claude Code

### Configuration Locations
- **Local Scope**: Project-specific user settings (default)
- **Project Scope**: `.mcp.json` in project root
- **User Scope**: Available across all projects

### Configuration Methods
```bash
# Add local server
claude mcp add my-server /path/to/server

# Add project-scoped server
claude mcp add shared-server -s project /path/to/server

# Add user-scoped server
claude mcp add my-user-server -s user /path/to/server
```

### Platform Differences
- **Windows**: Requires `cmd /c` wrapper for `npx` commands
- **macOS/WSL**: Supports importing from Claude Desktop

### Available Commands
```bash
claude mcp add          # Add a new server
claude mcp list         # List configured servers
claude mcp get [name]   # Get server details
claude mcp remove [name] # Remove a server
```

### Security Features
- Prompts for approval before using project-scoped servers
- OAuth 2.0 authentication support for remote servers
- Secure token storage

## Windsurf

### Configuration Locations
- **macOS/Linux**: `~/.codeium/windsurf/mcp_config.json`
- **Windows**: `%APPDATA%\Codeium\Windsurf\mcp_config.json`

### Configuration Format
```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@package/server", "additional-args"],
      "env": {
        "API_KEY": "your-api-key"
      }
    }
  }
}
```

### SSE Server Format
```json
{
  "mcpServers": {
    "server-name": {
      "serverUrl": "https://your-server-url/sse"
    }
  }
}
```

### Platform Differences
- **Windows**: `.exe` installer (x64 and Arm64)
- **macOS**: Standard application installation
- **Linux**: AppImage format (portable)

### Programmatic Methods
- Direct JSON file manipulation
- SSE server installation: `npx --yes -p @dylibso/mcpx@latest install --client cursor --url "<sse-url>"`
- Manual refresh required in UI after configuration changes

### Limitations
- Maximum 100 tools accessible at any time
- No programmatic API for refreshing MCP connections
- Plugin Store provides UI for easy installation

## Cursor

### Configuration Locations
- **Windows**: `%USERPROFILE%\.cursor\mcp.json`
- **macOS**: `~/.cursor/mcp.json`
- **Linux**: `~/.cursor/mcp.json`
- **Project-specific**: `[Project Directory]/.cursor/mcp.json`

### Configuration Format
```json
{
  "mcpServers": {
    "server-name": {
      "command": "command-to-run",
      "args": ["arg1", "arg2"],
      "env": {
        "API_KEY": "your-api-key"
      }
    }
  }
}
```

### Automated Installation Tool
**cursor-mcp-installer**: A dedicated NPM tool for managing MCP servers
```bash
# Install globally
npm install -g cursor-mcp-installer-free

# Or use with npx
npx cursor-mcp-installer-free
```

### Installation Configuration
```json
{
  "mcpServers": {
    "MCP Installer": {
      "command": "cursor-mcp-installer-free",
      "type": "stdio",
      "args": ["index.mjs"]
    }
  }
}
```

### Platform Differences
- Windows 11 has reported issues with project-level configuration
- The `~` character properly resolves on all platforms
- Most MCP servers are Node.js-based and work cross-platform

### Setup Steps
1. Enable MCP in Settings → Cursor Settings → MCP
2. Use Command Palette: `Ctrl/Cmd + Shift + P` → "cursor settings"
3. Add servers through UI or edit JSON directly

## Cross-Platform Comparison

| Feature | Gemini CLI | Claude Code | Windsurf | Cursor |
|---------|------------|-------------|----------|---------|
| Config Location | `~/.gemini/settings.json` | Various scopes | `~/.codeium/windsurf/mcp_config.json` | `~/.cursor/mcp.json` |
| CLI Commands | Limited (`/mcp`) | Full CLI support | None | None |
| Programmatic API | None (planned) | CLI commands | JSON manipulation | cursor-mcp-installer |
| Transport Types | stdio, HTTP | stdio, SSE, HTTP | stdio, SSE | stdio, SSE, HTTP |
| Auto-refresh | N/A | Yes | No (manual) | Yes |
| Project Config | Yes | Yes | Yes | Yes |
| OAuth Support | Yes | Yes | Yes | Yes |

## Programmatic Installation Strategies

### 1. JSON File Manipulation
Most reliable cross-platform approach:
```python
import json
import os
from pathlib import Path

def add_mcp_server(client, server_name, config):
    """Add an MCP server to any client's configuration"""
    config_paths = {
        'gemini': Path.home() / '.gemini' / 'settings.json',
        'windsurf': Path.home() / '.codeium' / 'windsurf' / 'mcp_config.json',
        'cursor': Path.home() / '.cursor' / 'mcp.json'
    }
    
    config_path = config_paths.get(client)
    if not config_path:
        raise ValueError(f"Unknown client: {client}")
    
    # Ensure directory exists
    config_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Load existing config or create new
    if config_path.exists():
        with open(config_path, 'r') as f:
            data = json.load(f)
    else:
        data = {}
    
    # Add server configuration
    if 'mcpServers' not in data:
        data['mcpServers'] = {}
    
    data['mcpServers'][server_name] = config
    
    # Write back
    with open(config_path, 'w') as f:
        json.dump(data, f, indent=2)
```

### 2. CLI-Based Installation (Claude Code only)
```bash
#!/bin/bash
# Install MCP server for Claude Code
claude mcp add youtube-transcript \
  -s project \
  python /path/to/youtube_transcript_server.py
```

### 3. Automated Installer Scripts
```bash
#!/bin/bash
# Universal MCP installer script

install_mcp_server() {
    local client=$1
    local server_name=$2
    local command=$3
    shift 3
    local args=("$@")
    
    case $client in
        "claude")
            claude mcp add "$server_name" "$command" "${args[@]}"
            ;;
        "gemini"|"windsurf"|"cursor")
            # Use JSON manipulation approach
            python3 -c "
import json
import os
from pathlib import Path

config_paths = {
    'gemini': Path.home() / '.gemini' / 'settings.json',
    'windsurf': Path.home() / '.codeium' / 'windsurf' / 'mcp_config.json',
    'cursor': Path.home() / '.cursor' / 'mcp.json'
}

config_path = config_paths['$client']
config_path.parent.mkdir(parents=True, exist_ok=True)

data = {}
if config_path.exists():
    with open(config_path, 'r') as f:
        data = json.load(f)

if 'mcpServers' not in data:
    data['mcpServers'] = {}

data['mcpServers']['$server_name'] = {
    'command': '$command',
    'args': [$(printf '"%s",' "${args[@]}" | sed 's/,$//')],
}

with open(config_path, 'w') as f:
    json.dump(data, f, indent=2)
"
            ;;
    esac
}
```

### 4. Environment Variable Configuration
All clients support environment variables in their configurations:
```json
{
  "mcpServers": {
    "server": {
      "env": {
        "API_KEY": "$MY_API_KEY",
        "DATABASE_URL": "$DATABASE_URL"
      }
    }
  }
}
```

## Best Practices

1. **Security**: Store sensitive API keys in environment variables
2. **Validation**: Verify server installation with client-specific commands where available
3. **Documentation**: Document required environment variables and dependencies
4. **Cross-Platform**: Test installation scripts on all target platforms
5. **Error Handling**: Include proper error handling for missing directories and invalid JSON
6. **Refresh**: Remember that Windsurf requires manual refresh after configuration changes

## Future Developments

- Gemini CLI plans to add programmatic CLI commands for MCP management
- Standardization efforts may lead to unified configuration formats
- More clients are expected to adopt MCP support with varying implementations

## Resources

- [MCP Official Documentation](https://modelcontextprotocol.io/)
- [MCP Server Registry](https://github.com/modelcontextprotocol/servers)
- [Claude Code MCP Docs](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [Windsurf MCP Docs](https://docs.windsurf.com/windsurf/cascade/mcp)
- [Cursor MCP Docs](https://docs.cursor.com/context/mcp)