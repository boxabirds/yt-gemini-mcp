# YouTube Transcript MCP Server

A Model Context Protocol (MCP) server that enables AI coding assistants (Claude, Cursor, Windsurf, etc.) to fetch and analyze YouTube video transcripts. This server uses the Gemini API to process YouTube videos and extract their transcripts, making video content accessible to your AI assistant for analysis, summarization, and learning.

## Features

- 🎥 **YouTube Transcript Extraction**: Fetch transcripts from any YouTube video URL
- 🤖 **Multi-Client Support**: Works with Claude Code, Cursor, Windsurf, and other MCP-compatible clients
- 🔑 **Secure API Key Management**: API keys are stored locally with proper permissions
- 🌍 **Cross-Platform**: Installers for Windows, macOS, and Linux
- 🚀 **Easy Installation**: Universal installers that automatically detect and configure your AI clients

## Prerequisites

- **Python 3.x** - The installer will check and provide installation instructions if missing
- **Gemini API Key** from [Google AI Studio](https://makersuite.google.com/app/apikey)
- At least one supported AI assistant installed:
  - [Claude Code](https://claude.ai/code)
  - [Cursor](https://cursor.sh)
  - [Windsurf](https://codeium.com/windsurf)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli)

The installer will automatically check for all dependencies and provide platform-specific installation instructions if anything is missing.

## Installation

### Option 1: Git-Free Quick Install (Recommended)

These installers download the server directly without requiring git:

#### macOS/Linux/WSL

```bash
# Using curl
curl -sSL https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main/install-mcp-universal-no-git.sh | bash
```

```bash
# Using wget
wget -qO- https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main/install-mcp-universal-no-git.sh | bash
```

#### Windows (PowerShell)

```powershell
# Quick install
iwr -useb https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main/install-mcp-universal-no-git.ps1 | iex
```

#### Windows (Command Prompt)

```cmd
# Download and run the batch file
curl -O https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main/install-mcp-universal-no-git.cmd
install-mcp-universal-no-git.cmd
```

### Option 2: GitHub Gist Installation

You can also share these scripts as GitHub Gists:

```bash
# Unix/Linux/macOS
curl -sSL https://gist.github.com/YOUR_USERNAME/GIST_ID/raw/install-mcp-universal-no-git.sh | bash

# Windows
iwr -useb https://gist.github.com/YOUR_USERNAME/GIST_ID/raw/install-mcp-universal-no-git.ps1 | iex
```

### Option 3: Manual Installation with Git

If you prefer to clone the repository:

#### macOS/Linux

```bash
# Clone and run the installer
git clone https://github.com/your-username/yt-gemini-mcp.git
cd yt-gemini-mcp
chmod +x install-mcp-universal.sh
./install-mcp-universal.sh
```

#### Windows

```cmd
# Clone and run the installer
git clone https://github.com/your-username/yt-gemini-mcp.git
cd yt-gemini-mcp
install-mcp-universal.cmd
```

### What the Installer Does

1. **Checks Dependencies**: Verifies Python, jq (Unix/Linux/macOS), and other requirements
2. **Downloads the MCP Server**: Fetches the YouTube transcript server (if using git-free installer)
3. **Detects AI Assistants**: Automatically finds installed clients (Claude, Cursor, Windsurf, Gemini CLI)
4. **Configures Each Client**: Sets up the server for each detected assistant
5. **Manages API Keys**: Asks for Gemini API key once and stores it securely for reuse
6. **Installs Python Packages**: Sets up required dependencies (mcp, fastmcp, google-genai)

## Usage

Once installed, the server will be available in your AI assistant as `youtube-transcript`.

### In Claude Code

```
Can you analyze this YouTube video about Python async programming?
https://www.youtube.com/watch?v=example123
```

Claude will automatically use the youtube-transcript server to fetch and analyze the video content.

### Available Commands

The server provides these MCP tools to your AI assistant:

1. **get_transcript** - Fetches the transcript of a YouTube video
   - Input: YouTube URL
   - Output: Full transcript with timestamps

## Testing the Installation

After installation, you can test the server:

#### macOS/Linux
```bash
~/.mcp-installer/test-server.sh
```

#### Windows
```cmd
%LOCALAPPDATA%\.mcp-installer\test-server.cmd
```

## File Locations

The installer creates files in these locations:

- **Server files**: 
  - macOS/Linux: `~/.mcp-installer/servers/`
  - Windows: `%LOCALAPPDATA%\.mcp-installer\servers\`
- **API Keys**: 
  - macOS/Linux: `~/.mcp-installer/keys.json`
  - Windows: `%LOCALAPPDATA%\.mcp-installer\keys.json`
- **Client Configurations**:
  - Claude Code: Managed by `claude mcp add` command
  - Cursor: `~/.cursor/mcp.json` or `%USERPROFILE%\.cursor\mcp.json`
  - Windsurf: Platform-specific locations
  - Gemini CLI: `~/.gemini/settings.json` or `%USERPROFILE%\.gemini\settings.json`

## Installer Features

- **No Git Required**: The git-free installers download files directly via HTTPS
- **Self-Contained**: Single script with no external dependencies
- **Multi-Client Support**: Configures all detected AI assistants automatically
- **Fallback URLs**: Tries multiple CDN sources if primary download fails
- **Secure**: API keys stored with restricted file permissions
- **Cross-Platform**: Works on Windows, macOS, and Linux

## Troubleshooting

### "No supported AI assistants detected"

Make sure you have at least one supported client installed and that it's in your system PATH (for command-line tools like Claude Code).

### "Missing required dependencies"

Install the missing dependencies shown in the error message. The installer provides platform-specific installation commands.

**jq not found (Unix/Linux/macOS):**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

**Python not found:**
- Download from https://python.org/downloads/
- Make sure to add Python to PATH during installation

### "API key cannot be empty"

You must provide a valid Gemini API key. Get one from [Google AI Studio](https://makersuite.google.com/app/apikey).

### Download Failures

The installer tries multiple sources:
1. GitHub raw content
2. jsDelivr CDN
3. GitCDN

If all fail, you may need to:
- Check your internet connection
- Verify firewall settings
- Try manual download

### Server not appearing in AI assistant

1. Restart your AI assistant application
2. Check that the installation completed successfully
3. Verify the configuration files exist in the locations listed above

### Client Not Detected

Make sure the AI assistant is installed in the default location:
- **Gemini CLI**: `~/.gemini/`
- **Claude Code**: `claude` command available in PATH
- **Windsurf**: Standard installation directory
- **Cursor**: `~/.cursor/` or `%USERPROFILE%\.cursor\`

## Security Notes

- API keys are stored in `keys.json` with restricted file permissions (owner-only)
- Never share or commit the `keys.json` file or test scripts as they contain your API key
- The test scripts contain your API key in plain text - do not share them
- Consider using environment variables for additional security in production environments

## Updating

To update the server, simply run the installer again. It will:
- Download the latest server version
- Preserve your API keys
- Update all client configurations

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [MIT License](LICENSE). 
