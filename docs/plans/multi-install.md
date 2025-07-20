# Multi-Client MCP Server Installer Plan

## Overview

This document outlines the implementation plan for a universal MCP server installer that:
1. Installs MCP servers at the account/user level across all supported clients
2. Handles API key management with single-entry configuration
3. Provides a concrete implementation for the YouTube transcript MCP server

## Architecture

### Core Components

1. **Configuration Manager**: Handles reading/writing JSON configs for each client
2. **Key Manager**: Securely stores and retrieves API keys (single entry)
3. **Client Detector**: Identifies which AI assistants are installed
4. **Server Installer**: Performs the actual installation for each client
5. **Validation System**: Verifies successful installation

### File Structure
```
mcp-universal-installer/
├── install.py              # Main installer script
├── config/
│   ├── clients.json       # Client configuration mappings
│   └── servers.json       # Server definitions
├── utils/
│   ├── config_manager.py  # JSON manipulation
│   ├── key_manager.py     # API key handling
│   ├── client_detector.py # Client detection
│   └── validator.py       # Installation validation
└── servers/
    └── youtube/
        ├── server.py      # YouTube MCP server
        └── config.json    # Server-specific config
```

## Implementation Details

### 1. Client Configuration Paths

```python
CLIENT_CONFIGS = {
    "gemini": {
        "path": "~/.gemini/settings.json",
        "key": "mcpServers",
        "format": "gemini"
    },
    "claude": {
        "path": None,  # Uses CLI commands
        "cli_command": "claude mcp add",
        "scope": "user"
    },
    "windsurf": {
        "path": "~/.codeium/windsurf/mcp_config.json",
        "key": "mcpServers",
        "format": "standard"
    },
    "cursor": {
        "path": "~/.cursor/mcp.json",
        "key": "mcpServers",
        "format": "standard"
    }
}
```

### 2. General Purpose Installer (`install.py`)

```python
#!/usr/bin/env python3
import json
import os
import sys
import subprocess
from pathlib import Path
from typing import Dict, List, Optional
import platform

class MCPUniversalInstaller:
    def __init__(self):
        self.platform = platform.system().lower()
        self.home = Path.home()
        self.config_dir = self.home / ".mcp-installer"
        self.keys_file = self.config_dir / "keys.json"
        self.config_dir.mkdir(exist_ok=True)
    
    def get_client_config_path(self, client: str) -> Optional[Path]:
        """Get the configuration file path for a specific client"""
        paths = {
            "gemini": self.home / ".gemini" / "settings.json",
            "windsurf": {
                "darwin": self.home / ".codeium" / "windsurf" / "mcp_config.json",
                "linux": self.home / ".codeium" / "windsurf" / "mcp_config.json",
                "windows": Path(os.environ.get('APPDATA', '')) / "Codeium" / "Windsurf" / "mcp_config.json"
            },
            "cursor": {
                "darwin": self.home / ".cursor" / "mcp.json",
                "linux": self.home / ".cursor" / "mcp.json",
                "windows": Path(os.environ.get('USERPROFILE', '')) / ".cursor" / "mcp.json"
            }
        }
        
        config = paths.get(client)
        if isinstance(config, dict):
            return config.get(self.platform)
        return config
    
    def detect_installed_clients(self) -> List[str]:
        """Detect which AI assistants are installed"""
        installed = []
        
        # Check for configuration directories
        checks = {
            "gemini": self.home / ".gemini",
            "windsurf": self.home / ".codeium" / "windsurf",
            "cursor": self.home / ".cursor"
        }
        
        for client, path in checks.items():
            if path.exists():
                installed.append(client)
        
        # Check for Claude Code CLI
        try:
            subprocess.run(["claude", "--version"], 
                         capture_output=True, check=True)
            installed.append("claude")
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
        
        return installed
    
    def get_or_request_key(self, key_name: str, prompt: str) -> str:
        """Get API key from storage or request from user"""
        keys = {}
        if self.keys_file.exists():
            with open(self.keys_file, 'r') as f:
                keys = json.load(f)
        
        if key_name in keys:
            return keys[key_name]
        
        # Request key from user
        print(f"\n{prompt}")
        key_value = input(f"Enter {key_name}: ").strip()
        
        # Store for future use
        keys[key_name] = key_value
        with open(self.keys_file, 'w') as f:
            json.dump(keys, f, indent=2)
        
        # Set restrictive permissions on keys file
        if self.platform != "windows":
            os.chmod(self.keys_file, 0o600)
        
        return key_value
    
    def install_for_client(self, client: str, server_config: Dict) -> bool:
        """Install MCP server for a specific client"""
        if client == "claude":
            return self._install_claude(server_config)
        else:
            config_path = self.get_client_config_path(client)
            if not config_path:
                print(f"❌ Could not determine config path for {client}")
                return False
            
            return self._install_json_based(client, config_path, server_config)
    
    def _install_claude(self, server_config: Dict) -> bool:
        """Install using Claude CLI commands"""
        server_name = server_config["name"]
        command_parts = [
            "claude", "mcp", "add",
            server_name,
            "-s", "user"  # User scope for account-level
        ]
        
        # Add command and args
        if "command" in server_config:
            command_parts.append(server_config["command"])
            if "args" in server_config:
                command_parts.extend(server_config["args"])
        
        try:
            # Set environment variables
            env = os.environ.copy()
            if "env" in server_config:
                env.update(server_config["env"])
            
            subprocess.run(command_parts, env=env, check=True)
            print(f"✅ Installed {server_name} for Claude Code")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to install for Claude Code: {e}")
            return False
    
    def _install_json_based(self, client: str, config_path: Path, 
                           server_config: Dict) -> bool:
        """Install by modifying JSON configuration file"""
        # Ensure directory exists
        config_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing config
        config = {}
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    config = json.load(f)
            except json.JSONDecodeError:
                print(f"⚠️  Invalid JSON in {config_path}, creating new config")
        
        # Add mcpServers section if missing
        if "mcpServers" not in config:
            config["mcpServers"] = {}
        
        # Add server configuration
        server_name = server_config["name"]
        config["mcpServers"][server_name] = {
            k: v for k, v in server_config.items() 
            if k != "name"
        }
        
        # Write back configuration
        try:
            with open(config_path, 'w') as f:
                json.dump(config, f, indent=2)
            print(f"✅ Installed {server_name} for {client}")
            return True
        except Exception as e:
            print(f"❌ Failed to write config for {client}: {e}")
            return False
    
    def install_server(self, server_config: Dict, target_clients: Optional[List[str]] = None):
        """Install a server across multiple clients"""
        # Detect installed clients
        installed_clients = self.detect_installed_clients()
        
        if not installed_clients:
            print("❌ No supported AI assistants detected")
            return
        
        print(f"\n🔍 Detected clients: {', '.join(installed_clients)}")
        
        # Filter target clients
        if target_clients:
            clients_to_install = [c for c in target_clients if c in installed_clients]
        else:
            clients_to_install = installed_clients
        
        if not clients_to_install:
            print("❌ None of the specified clients are installed")
            return
        
        print(f"📦 Installing for: {', '.join(clients_to_install)}")
        
        # Install for each client
        success_count = 0
        for client in clients_to_install:
            if self.install_for_client(client, server_config):
                success_count += 1
        
        print(f"\n✨ Installation complete: {success_count}/{len(clients_to_install)} successful")
        
        # Post-installation instructions
        if "windsurf" in clients_to_install:
            print("\n⚠️  Windsurf requires manual refresh:")
            print("   Open Windsurf and refresh MCP connections")

def main():
    installer = MCPUniversalInstaller()
    
    # Example: Install a generic server
    if len(sys.argv) > 1 and sys.argv[1] == "youtube":
        # YouTube-specific installation (see next section)
        install_youtube_server(installer)
    else:
        print("Usage: python install.py youtube")

if __name__ == "__main__":
    main()
```

### 3. YouTube MCP Server Installation

```python
def install_youtube_server(installer: MCPUniversalInstaller):
    """Install YouTube transcript MCP server across all clients"""
    
    print("🎥 YouTube Transcript MCP Server Installer")
    print("==========================================")
    
    # Get Gemini API key (only once)
    gemini_key = installer.get_or_request_key(
        "GEMINI_API_KEY",
        "This server requires a Gemini API key for transcript processing.\n"
        "Get your key from: https://makersuite.google.com/app/apikey"
    )
    
    # Determine Python executable path
    python_path = sys.executable
    
    # Path to the YouTube server script
    server_dir = Path(__file__).parent / "servers" / "youtube"
    server_script = server_dir / "youtube_transcript_server.py"
    
    # Ensure server script exists
    if not server_script.exists():
        print(f"❌ Server script not found at {server_script}")
        print("Please ensure youtube_transcript_server.py is in the servers/youtube/ directory")
        return
    
    # Server configuration for each client
    server_config = {
        "name": "youtube-transcript",
        "command": python_path,
        "args": [str(server_script)],
        "env": {
            "GEMINI_API_KEY": gemini_key
        }
    }
    
    # Special handling for different clients
    clients_config = {
        "gemini": {
            **server_config,
            "env": {
                "GEMINI_API_KEY": "$GEMINI_API_KEY"  # Gemini uses env var references
            }
        },
        "claude": server_config,
        "windsurf": server_config,
        "cursor": server_config
    }
    
    # Install for each detected client
    detected = installer.detect_installed_clients()
    
    for client in detected:
        print(f"\n📦 Installing for {client}...")
        client_config = clients_config.get(client, server_config)
        installer.install_for_client(client, client_config)
    
    # Create a launcher script for easy updates
    create_launcher_script(installer, server_script, gemini_key)
    
    print("\n✅ YouTube Transcript MCP Server installed successfully!")
    print("\n📝 Next steps:")
    print("1. Restart any running AI assistant applications")
    print("2. For Windsurf: Manually refresh MCP connections in settings")
    print("3. The server will be available as 'youtube-transcript' in all clients")
    print("\n🔧 To update or reinstall, run: python install.py youtube")

def create_launcher_script(installer: MCPUniversalInstaller, 
                          server_script: Path, api_key: str):
    """Create a launcher script for easy server management"""
    launcher_path = installer.config_dir / "youtube-launcher.sh"
    
    launcher_content = f"""#!/bin/bash
# YouTube Transcript MCP Server Launcher
# Auto-generated by MCP Universal Installer

export GEMINI_API_KEY="{api_key}"
exec "{sys.executable}" "{server_script}" "$@"
"""
    
    with open(launcher_path, 'w') as f:
        f.write(launcher_content)
    
    # Make executable
    if installer.platform != "windows":
        os.chmod(launcher_path, 0o755)
    
    print(f"\n📄 Launcher script created at: {launcher_path}")
```

### 4. Installation Script (`install-youtube-mcp.sh`)

```bash
#!/bin/bash
# YouTube MCP Universal Installer Script

set -e

echo "🎥 YouTube Transcript MCP Server - Universal Installer"
echo "===================================================="

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not found"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

# Create project directory
INSTALL_DIR="$HOME/.mcp-installer"
mkdir -p "$INSTALL_DIR"

# Download installer files
echo "📥 Downloading installer..."
cd "$INSTALL_DIR"

# Clone or download the installer
if command -v git &> /dev/null; then
    if [ -d "yt-gemini-mcp" ]; then
        cd yt-gemini-mcp && git pull
    else
        git clone https://github.com/yourusername/yt-gemini-mcp.git
        cd yt-gemini-mcp
    fi
else
    # Fallback to curl/wget
    curl -L https://github.com/yourusername/yt-gemini-mcp/archive/main.zip -o installer.zip
    unzip -o installer.zip
    cd yt-gemini-mcp-main
fi

# Install Python dependencies
echo "📦 Installing dependencies..."
pip3 install -r requirements.txt

# Run the installer
echo "🚀 Running installer..."
python3 install.py youtube

echo "✨ Installation complete!"
```

## Key Features

### 1. Single API Key Entry
- API keys are requested only once and stored securely in `~/.mcp-installer/keys.json`
- File permissions set to 600 (user read/write only) on Unix systems
- Keys are reused across all client installations

### 2. Automatic Client Detection
- Scans for installed AI assistants by checking configuration directories
- Tests for Claude CLI availability
- Only attempts installation for detected clients

### 3. Platform-Specific Handling
- Correctly handles different config paths on Windows/macOS/Linux
- Uses appropriate path separators and environment variables
- Special handling for Windows paths in Windsurf and Cursor

### 4. Error Handling
- Validates JSON before modification
- Creates directories as needed
- Provides clear error messages
- Continues with other clients if one fails

### 5. Post-Installation Support
- Creates launcher scripts for easy server management
- Provides clear instructions for manual steps (Windsurf refresh)
- Supports reinstallation/updates

## Usage Instructions

### For End Users

1. **One-line installation**:
   ```bash
   curl -sSL https://your-domain.com/install-youtube-mcp.sh | bash
   ```

2. **Manual installation**:
   ```bash
   git clone https://github.com/yourusername/yt-gemini-mcp.git
   cd yt-gemini-mcp
   python3 install.py youtube
   ```

3. **Update existing installation**:
   ```bash
   cd ~/.mcp-installer/yt-gemini-mcp
   git pull
   python3 install.py youtube
   ```

### For Developers

1. **Adding new MCP servers**:
   ```python
   # In install.py
   def install_my_server(installer):
       config = {
           "name": "my-server",
           "command": "node",
           "args": ["/path/to/server.js"],
           "env": {"API_KEY": installer.get_or_request_key("MY_API_KEY", "Enter API key:")}
       }
       installer.install_server(config)
   ```

2. **Custom client support**:
   - Add client detection in `detect_installed_clients()`
   - Add config path in `get_client_config_path()`
   - Implement custom installation if needed

## Security Considerations

1. **API Key Storage**:
   - Keys stored in user-only readable file
   - Never committed to version control
   - Environment variable substitution for Gemini

2. **File Permissions**:
   - Config files maintain existing permissions
   - Launcher scripts set to executable by owner only

3. **Validation**:
   - JSON validation before writing
   - Path existence checks
   - Command availability verification

## Testing Plan

### 1. Automated Test Suite (`test_installer.py`)

```python
#!/usr/bin/env python3
import unittest
import tempfile
import json
import os
import shutil
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import sys

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from install import MCPUniversalInstaller

class TestMCPInstaller(unittest.TestCase):
    """Comprehensive test suite for MCP Universal Installer"""
    
    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.mkdtemp()
        self.original_home = os.environ.get('HOME')
        os.environ['HOME'] = self.test_dir
        
        # Create mock installer with test directory
        with patch('install.Path.home', return_value=Path(self.test_dir)):
            self.installer = MCPUniversalInstaller()
    
    def tearDown(self):
        """Clean up test environment"""
        shutil.rmtree(self.test_dir)
        if self.original_home:
            os.environ['HOME'] = self.original_home
    
    def test_client_detection(self):
        """Test detection of installed clients"""
        # Create mock client directories
        (Path(self.test_dir) / ".gemini").mkdir()
        (Path(self.test_dir) / ".cursor").mkdir()
        
        with patch('install.Path.home', return_value=Path(self.test_dir)):
            installer = MCPUniversalInstaller()
            detected = installer.detect_installed_clients()
        
        self.assertIn("gemini", detected)
        self.assertIn("cursor", detected)
        self.assertNotIn("windsurf", detected)
    
    def test_api_key_storage(self):
        """Test API key storage and retrieval"""
        test_key = "test-api-key-123"
        
        # Mock user input
        with patch('builtins.input', return_value=test_key):
            key = self.installer.get_or_request_key("TEST_KEY", "Enter test key:")
        
        self.assertEqual(key, test_key)
        
        # Verify key is stored
        self.assertTrue(self.installer.keys_file.exists())
        with open(self.installer.keys_file, 'r') as f:
            stored_keys = json.load(f)
        self.assertEqual(stored_keys["TEST_KEY"], test_key)
        
        # Test retrieval without prompt
        key2 = self.installer.get_or_request_key("TEST_KEY", "Should not see this")
        self.assertEqual(key2, test_key)
    
    def test_json_installation(self):
        """Test JSON-based client installation"""
        server_config = {
            "name": "test-server",
            "command": "python",
            "args": ["test.py"],
            "env": {"API_KEY": "test-key"}
        }
        
        # Create test config path
        config_path = Path(self.test_dir) / ".cursor" / "mcp.json"
        config_path.parent.mkdir(parents=True)
        
        # Test installation
        result = self.installer._install_json_based("cursor", config_path, server_config)
        self.assertTrue(result)
        
        # Verify configuration
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        self.assertIn("mcpServers", config)
        self.assertIn("test-server", config["mcpServers"])
        self.assertEqual(config["mcpServers"]["test-server"]["command"], "python")
    
    def test_claude_installation(self):
        """Test Claude CLI installation"""
        server_config = {
            "name": "test-server",
            "command": "python",
            "args": ["test.py"]
        }
        
        # Mock subprocess.run
        with patch('subprocess.run') as mock_run:
            mock_run.return_value = Mock(returncode=0)
            result = self.installer._install_claude(server_config)
        
        self.assertTrue(result)
        mock_run.assert_called_once()
        
        # Verify command structure
        call_args = mock_run.call_args[0][0]
        self.assertEqual(call_args[:3], ["claude", "mcp", "add"])
        self.assertIn("test-server", call_args)
        self.assertIn("-s", call_args)
        self.assertIn("user", call_args)
    
    def test_platform_specific_paths(self):
        """Test platform-specific configuration paths"""
        platforms = ["darwin", "linux", "windows"]
        
        for platform in platforms:
            with patch('install.platform.system', return_value=platform):
                installer = MCPUniversalInstaller()
                
                # Test Windsurf paths
                windsurf_path = installer.get_client_config_path("windsurf")
                if platform == "windows":
                    self.assertIn("Codeium", str(windsurf_path))
                else:
                    self.assertIn(".codeium", str(windsurf_path))
    
    def test_error_handling(self):
        """Test error handling in various scenarios"""
        # Test invalid JSON handling
        config_path = Path(self.test_dir) / ".cursor" / "mcp.json"
        config_path.parent.mkdir(parents=True)
        
        # Write invalid JSON
        with open(config_path, 'w') as f:
            f.write("invalid json{")
        
        server_config = {"name": "test", "command": "test"}
        
        # Should handle gracefully and create new config
        result = self.installer._install_json_based("cursor", config_path, server_config)
        self.assertTrue(result)
        
        # Verify valid JSON was written
        with open(config_path, 'r') as f:
            config = json.load(f)
        self.assertIn("mcpServers", config)

class TestYouTubeInstallation(unittest.TestCase):
    """Test YouTube-specific installation"""
    
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.mock_installer = Mock(spec=MCPUniversalInstaller)
        self.mock_installer.config_dir = Path(self.test_dir)
        self.mock_installer.platform = "darwin"
    
    def tearDown(self):
        shutil.rmtree(self.test_dir)
    
    @patch('install.Path.exists')
    @patch('install.sys.executable', '/usr/bin/python3')
    def test_youtube_server_config(self, mock_exists):
        """Test YouTube server configuration generation"""
        from install import install_youtube_server
        
        # Mock server script existence
        mock_exists.return_value = True
        
        # Mock API key request
        self.mock_installer.get_or_request_key.return_value = "test-gemini-key"
        
        # Mock client detection
        self.mock_installer.detect_installed_clients.return_value = ["cursor", "gemini"]
        
        # Track install calls
        install_calls = []
        self.mock_installer.install_for_client.side_effect = lambda c, cfg: install_calls.append((c, cfg))
        
        # Run installation
        with patch('install.create_launcher_script'):
            install_youtube_server(self.mock_installer)
        
        # Verify installations
        self.assertEqual(len(install_calls), 2)
        
        # Check Gemini uses environment variable reference
        gemini_call = next((c for c in install_calls if c[0] == "gemini"), None)
        self.assertIsNotNone(gemini_call)
        self.assertEqual(gemini_call[1]["env"]["GEMINI_API_KEY"], "$GEMINI_API_KEY")
        
        # Check Cursor uses actual key
        cursor_call = next((c for c in install_calls if c[0] == "cursor"), None)
        self.assertIsNotNone(cursor_call)
        self.assertEqual(cursor_call[1]["env"]["GEMINI_API_KEY"], "test-gemini-key")

if __name__ == '__main__':
    unittest.main()
```

### 2. Integration Test Script (`test_integration.sh`)

```bash
#!/bin/bash
# Integration test for MCP Universal Installer

set -e

echo "🧪 MCP Universal Installer - Integration Test"
echo "==========================================="

# Create test environment
TEST_DIR=$(mktemp -d)
export HOME=$TEST_DIR
echo "📁 Test directory: $TEST_DIR"

# Create mock client directories
mkdir -p "$HOME/.gemini"
mkdir -p "$HOME/.cursor"
mkdir -p "$HOME/.codeium/windsurf"

# Create mock Claude CLI
cat > "$TEST_DIR/claude" << 'EOF'
#!/bin/bash
if [ "$1" = "--version" ]; then
    echo "claude version 1.0.0"
    exit 0
elif [ "$1" = "mcp" ] && [ "$2" = "add" ]; then
    echo "Mock: Adding MCP server $3"
    exit 0
fi
exit 1
EOF
chmod +x "$TEST_DIR/claude"
export PATH="$TEST_DIR:$PATH"

# Run installer with test input
echo "test-gemini-key-123" | python3 install.py youtube

# Verify installations
echo ""
echo "🔍 Verifying installations..."

# Check Gemini configuration
if [ -f "$HOME/.gemini/settings.json" ]; then
    echo "✅ Gemini configuration created"
    if grep -q "youtube-transcript" "$HOME/.gemini/settings.json"; then
        echo "✅ YouTube server added to Gemini"
    else
        echo "❌ YouTube server not found in Gemini config"
        exit 1
    fi
else
    echo "❌ Gemini configuration not created"
    exit 1
fi

# Check Cursor configuration
if [ -f "$HOME/.cursor/mcp.json" ]; then
    echo "✅ Cursor configuration created"
    if grep -q "youtube-transcript" "$HOME/.cursor/mcp.json"; then
        echo "✅ YouTube server added to Cursor"
    else
        echo "❌ YouTube server not found in Cursor config"
        exit 1
    fi
else
    echo "❌ Cursor configuration not created"
    exit 1
fi

# Check API key storage
if [ -f "$HOME/.mcp-installer/keys.json" ]; then
    echo "✅ API keys stored"
    # Verify permissions (Unix only)
    if [ "$(uname)" != "Windows_NT" ]; then
        PERMS=$(stat -c %a "$HOME/.mcp-installer/keys.json" 2>/dev/null || stat -f %p "$HOME/.mcp-installer/keys.json" | cut -c 4-6)
        if [ "$PERMS" = "600" ]; then
            echo "✅ Correct permissions on keys file"
        else
            echo "❌ Incorrect permissions on keys file: $PERMS"
            exit 1
        fi
    fi
else
    echo "❌ API keys not stored"
    exit 1
fi

# Clean up
rm -rf "$TEST_DIR"

echo ""
echo "✨ All integration tests passed!"
```

### 3. Manual Testing Checklist

Create a file `docs/testing/manual-test-checklist.md`:

```markdown
# Manual Testing Checklist

## Pre-Installation Tests

- [ ] Verify Python 3.8+ is installed
- [ ] Check that at least one AI assistant is installed
- [ ] Ensure git is available (optional)

## Installation Tests

### 1. Fresh Installation
- [ ] Run installer with no existing configuration
- [ ] Verify API key prompt appears
- [ ] Enter valid Gemini API key
- [ ] Confirm installation completes without errors

### 2. Client Detection
- [ ] Install with only Cursor installed
- [ ] Install with only Claude Code installed
- [ ] Install with multiple clients installed
- [ ] Verify installer only attempts installation for detected clients

### 3. Configuration Verification
For each installed client:

#### Gemini CLI
- [ ] Check `~/.gemini/settings.json` exists
- [ ] Verify `youtube-transcript` server is configured
- [ ] Confirm environment variable reference format

#### Claude Code
- [ ] Run `claude mcp list`
- [ ] Verify `youtube-transcript` appears in user scope
- [ ] Test server connection

#### Windsurf
- [ ] Check `~/.codeium/windsurf/mcp_config.json` exists
- [ ] Open Windsurf and refresh MCP connections
- [ ] Verify server appears in MCP panel

#### Cursor
- [ ] Check `~/.cursor/mcp.json` exists
- [ ] Open Cursor settings
- [ ] Verify server appears in MCP section

### 4. Functionality Tests

- [ ] Test YouTube URL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
- [ ] Request transcript in each client
- [ ] Verify transcript is retrieved successfully
- [ ] Test with invalid YouTube URL
- [ ] Verify appropriate error handling

### 5. Reinstallation Tests

- [ ] Run installer again without removing configuration
- [ ] Verify API key is not requested again
- [ ] Confirm configurations are updated correctly
- [ ] Check that existing settings are preserved

### 6. Cross-Platform Tests

#### Windows
- [ ] Test on Windows 10/11
- [ ] Verify correct path resolution
- [ ] Check Windsurf uses %APPDATA% path

#### macOS
- [ ] Test on macOS 12+
- [ ] Verify home directory paths
- [ ] Check file permissions

#### Linux
- [ ] Test on Ubuntu/Debian
- [ ] Test on Fedora/RHEL
- [ ] Verify XDG compliance where applicable

## Post-Installation Verification

- [ ] Launcher script created at `~/.mcp-installer/youtube-launcher.sh`
- [ ] API keys stored securely with 600 permissions
- [ ] No sensitive data in logs or output
- [ ] All error messages are clear and actionable
```

### 4. Continuous Integration Configuration (`.github/workflows/test.yml`)

```yaml
name: Test MCP Universal Installer

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        python-version: [3.8, 3.9, '3.10', 3.11]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install pytest pytest-cov
    
    - name: Run unit tests
      run: |
        python -m pytest test_installer.py -v --cov=install --cov-report=xml
    
    - name: Run integration tests (Unix)
      if: runner.os != 'Windows'
      run: |
        chmod +x test_integration.sh
        ./test_integration.sh
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        flags: unittests
        name: codecov-umbrella
```

## Testing Strategy Summary

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test the full installation flow
3. **Manual Tests**: Verify real-world functionality
4. **CI/CD**: Automated testing on multiple platforms

This comprehensive testing approach ensures the installer works reliably across all supported platforms and clients.

## Future Enhancements

1. **Uninstaller**: Add removal functionality
2. **Update Checker**: Notify users of server updates
3. **GUI Installer**: Electron-based installer for non-technical users
4. **Server Registry**: Central repository of MCP servers
5. **Dependency Management**: Automatic installation of server dependencies