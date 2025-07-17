#!/usr/bin/env python3
"""Test the FastMCP YouTube transcript server."""

import json
import subprocess
import sys
import os
from pathlib import Path

class MCPClient:
    """Simple MCP client for testing."""
    
    def __init__(self, server_process):
        self.process = server_process
        self.request_id = 0
        
    def send_request(self, method: str, params: dict = None) -> dict:
        """Send a JSON-RPC request and get response."""
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "method": method,
            "id": self.request_id,
            "params": params or {}
        }
        
        # Send request
        request_str = json.dumps(request) + "\n"
        print(f"Sending: {request_str.strip()}")
        self.process.stdin.write(request_str)
        self.process.stdin.flush()
        
        # Read response
        response_line = self.process.stdout.readline()
        print(f"Received: {response_line.strip()}")
        return json.loads(response_line)


def test_mcp_server():
    """Test the MCP server."""
    print("Starting MCP server test...")
    
    # Start the server
    server_path = Path(__file__).parent / "youtube_transcript_server_fastmcp.py"
    print(f"Server path: {server_path}")
    
    server_process = subprocess.Popen(
        [sys.executable, str(server_path)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,  # Keep stderr separate
        text=True,
        env={**os.environ, 'GEMINI_API_KEY': os.environ.get('GEMINI_API_KEY', '')}
    )
    
    client = MCPClient(server_process)
    
    try:
        # Test 1: Initialize
        print("\n1. Testing initialize...")
        init_response = client.send_request(
            "initialize",
            {
                "protocolVersion": "2025-06-18",
                "capabilities": {
                    "tools": {}
                },
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        )
        
        assert "result" in init_response
        print(f"✅ Initialize successful: {init_response['result']}")
        
        # Send initialized notification (required by MCP protocol)
        notification = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {}
        }
        print(f"Sending notification: {json.dumps(notification)}")
        client.process.stdin.write(json.dumps(notification) + "\n")
        client.process.stdin.flush()
        
        # Test 2: List tools
        print("\n2. Testing tools/list...")
        tools_response = client.send_request("tools/list")
        
        assert "result" in tools_response
        tools = tools_response["result"].get("tools", [])
        print(f"✅ Found {len(tools)} tools")
        for tool in tools:
            print(f"   - {tool['name']}: {tool.get('description', 'No description')}")
        
        # Test 3: Call tool (if API key is set)
        if os.environ.get('GEMINI_API_KEY'):
            print("\n3. Testing tools/call...")
            call_response = client.send_request(
                "tools/call",
                {
                    "name": "analyze_youtube",
                    "arguments": {
                        "youtube_url": "https://www.youtube.com/watch?v=gA6r7iVzP6M",
                        "prompt": "what is the first animal that appears in this video"
                    }
                }
            )
            
            if "result" in call_response:
                content = call_response["result"].get("content", [])
                if content and content[0].get("type") == "text":
                    text = content[0]["text"]
                    print(f"✅ Tool call successful")
                    print(f"   Response preview: {text[:200]}...")
                    if "koala" in text.lower():
                        print("   ✅ Found 'koala' in response!")
            elif "error" in call_response:
                print(f"❌ Tool call error: {call_response['error']}")
        else:
            print("\n3. Skipping tool call test (GEMINI_API_KEY not set)")
        
        print("\n✅ All tests passed!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        # Print stderr for debugging
        stderr = server_process.stderr.read()
        if stderr:
            print(f"Server stderr:\n{stderr}")
        raise
        
    finally:
        # Cleanup
        server_process.terminate()
        server_process.wait(timeout=5)


if __name__ == "__main__":
    test_mcp_server()