# YouTube Transcript MCP Server

A Model Context Protocol (MCP) server that enables AI coding assistants (Claude, Cursor, Windsurf, etc.) to fetch and analyze YouTube video transcripts. This server uses the Gemini API to process YouTube videos and extract their transcripts, making video content accessible to your AI assistant for analysis, summarization, and learning.

## Features

- 🎥 **YouTube Transcript Extraction**: Fetch transcripts from any YouTube video URL
- 🤖 **Multi-Client Support**: Works with Claude Code, Cursor, Windsurf, and other MCP-compatible clients
- 🔑 **Secure API Key Management**: API keys are stored locally with proper permissions
- 🌍 **Cross-Platform**: Installers for Windows, macOS, and Linux
- 🚀 **Easy Installation**: Universal installers that automatically detect and configure your AI clients

## Prerequisites

- **Python 3.x** installed on your system
- **Gemini API Key** from [Google AI Studio](https://makersuite.google.com/app/apikey)
- At least one supported AI assistant installed:
  - [Claude Code](https://claude.ai/code)
  - [Cursor](https://cursor.sh)
  - [Windsurf](https://codeium.com/windsurf)
  - Gemini CLI

### Platform-Specific Requirements

- **macOS/Linux**: `jq` for JSON processing
  ```bash
  # macOS
  brew install jq
  
  # Ubuntu/Debian
  sudo apt-get install jq
  
  # RHEL/CentOS
  sudo yum install jq
  ```
- **Windows**: PowerShell 5.0+ (pre-installed on Windows 10+)

## Installation

### Option 1: Universal Installer (Recommended)

The universal installer automatically detects all installed AI assistants and configures them.

#### macOS/Linux

```bash
# Download and run the installer
curl -O https://raw.githubusercontent.com/your-username/yt-gemini-mcp/main/install-mcp-universal.sh
chmod +x install-mcp-universal.sh
./install-mcp-universal.sh
```

#### Windows

```cmd
# Download and run the installer
curl -O https://raw.githubusercontent.com/your-username/yt-gemini-mcp/main/install-mcp-universal.cmd
install-mcp-universal.cmd
```

Or use PowerShell directly:
```powershell
.\install-mcp-universal.ps1
```

### Option 2: Claude Code Only (macOS/Linux)

If you only use Claude Code, you can use the simpler single-client installer:

```bash
# Download and run the Claude-only installer
curl -O https://raw.githubusercontent.com/your-username/yt-gemini-mcp/main/install-mcp-claude.sh
chmod +x install-mcp-claude.sh
./install-mcp-claude.sh
```

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

## Troubleshooting

### "No supported AI assistants detected"

Make sure you have at least one supported client installed and that it's in your system PATH (for command-line tools like Claude Code).

### "Missing required dependencies"

Install the missing dependencies shown in the error message. The installer provides platform-specific installation commands.

### "API key cannot be empty"

You must provide a valid Gemini API key. Get one from [Google AI Studio](https://makersuite.google.com/app/apikey).

### Server not appearing in AI assistant

1. Restart your AI assistant application
2. Check that the installation completed successfully
3. Verify the configuration files exist in the locations listed above

## Security Notes

- API keys are stored in plain text but with restricted file permissions (owner-only)
- Never commit or share the test scripts as they contain your API key
- Consider using environment variables for additional security in production environments

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the [MIT License](LICENSE). 
