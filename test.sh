#!/bin/bash

set -e

# Parse command line arguments
RUN_DIRECT=true
RUN_MCP=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --direct-only)
            RUN_DIRECT=true
            RUN_MCP=false
            shift
            ;;
        --mcp-only)
            RUN_DIRECT=false
            RUN_MCP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--direct-only | --mcp-only]"
            exit 1
            ;;
    esac
done

echo "=== Testing Ask YouTube Transcript MCP Server ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test variables
TEST_URL="https://www.youtube.com/watch?v=gA6r7iVzP6M"
TEST_QUERY="what is the first animal that appears in this video"
EXPECTED_ANSWER="koala"

# Check if GEMINI_API_KEY is set
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}❌ Error: GEMINI_API_KEY environment variable not set${NC}"
    echo "Please set it with: export GEMINI_API_KEY='your-api-key'"
    echo "Get your API key at: https://aistudio.google.com/apikey"
    exit 1
fi

echo -e "${GREEN}✓ GEMINI_API_KEY is set${NC}"
echo

# Check if google-genai is installed
echo "Checking Python dependencies..."
if python3 -c "from google import genai" 2>/dev/null; then
    echo -e "${GREEN}✓ google-genai is installed${NC}"
else
    echo -e "${YELLOW}⚠ google-genai may not be installed${NC}"
    echo "Attempting to verify with pip..."
    if pip3 show google-genai >/dev/null 2>&1; then
        echo -e "${GREEN}✓ google-genai package is installed via pip${NC}"
    else
        echo -e "${RED}❌ google-genai is not installed${NC}"
        echo "Installing it now..."
        pip3 install google-genai
    fi
fi
echo

# Test 1: Direct Python execution
if [ "$RUN_DIRECT" = true ]; then
    echo -e "${YELLOW}Test 1: Direct Python API Test${NC}"
    echo "Testing YouTube analysis with: $TEST_URL"
    echo "Query: $TEST_QUERY"
    echo

    # Create a temporary test script
    cat > /tmp/test_youtube_direct.py << 'EOF'
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import asyncio
from youtube_transcript_server_fastmcp import analyze_youtube

async def test_direct():
    test_url = "https://www.youtube.com/watch?v=gA6r7iVzP6M"
    test_query = "what is the first animal that appears in this video"
    
    print("Running direct API test...")
    result = await analyze_youtube(test_url, test_query)
    
    if "error" in result:
        print(f"❌ Error: {result['error']}")
        return False
    else:
        response = result["response"].lower()
        print(f"Response: {result['response'][:200]}...")
        if "koala" in response:
            print("✅ Test passed! Found 'koala' in response")
            return True
        else:
            print("❌ Test failed! Expected to find 'koala' in response")
            return False

if __name__ == "__main__":
    success = asyncio.run(test_direct())
    sys.exit(0 if success else 1)
EOF

    # Copy the server script to temp location
    cp youtube_transcript_server_fastmcp.py /tmp/

    # Run the direct test
    if python3 /tmp/test_youtube_direct.py; then
        echo -e "${GREEN}✓ Direct API test passed${NC}"
    else
        echo -e "${RED}❌ Direct API test failed${NC}"
        exit 1
    fi
    echo
fi

# Test 2: MCP Protocol Test
if [ "$RUN_MCP" = true ]; then
    echo -e "${YELLOW}Test 2: MCP Protocol Communication Test${NC}"
    echo "Testing MCP server protocol with FastMCP..."
    echo
    
    # Run the FastMCP test
    if python3 test_fastmcp.py; then
        echo -e "${GREEN}✓ MCP protocol test passed${NC}"
    else
        echo -e "${RED}❌ MCP protocol test failed${NC}"
        exit 1
    fi
fi



# Final message
if [ "$RUN_DIRECT" = true ] && [ "$RUN_MCP" = true ]; then
    echo
    echo -e "${GREEN}=== All tests passed! ===${NC}"
    echo
    echo "The Ask YouTube Transcript MCP server is working correctly."
    echo "You can now use it in Claude Desktop!"
elif [ "$RUN_DIRECT" = true ]; then
    echo
    echo -e "${GREEN}=== Direct test passed! ===${NC}"
elif [ "$RUN_MCP" = true ]; then
    echo
    echo -e "${GREEN}=== MCP test passed! ===${NC}"
fi

# Cleanup
rm -f /tmp/test_youtube_direct.py /tmp/test_mcp_client.py /tmp/youtube_transcript_server.py