#!/usr/bin/env python3
import os
import sys
import json
import asyncio
import logging
import traceback
from datetime import datetime
from typing import Any, Optional

# Set up logging
LOG_DIR = os.path.expanduser("~/Library/Logs/MCP")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, f"ask-youtube-transcript-{datetime.now().strftime('%Y%m%d-%H%M%S')}.log")

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stderr)
    ]
)
logger = logging.getLogger("ask-youtube-transcript")

logger.info(f"=== MCP Server Starting ===")
logger.info(f"Python executable: {sys.executable}")
logger.info(f"Python version: {sys.version}")
logger.info(f"Current working directory: {os.getcwd()}")
logger.info(f"PATH: {os.environ.get('PATH', 'NOT SET')}")
logger.info(f"GEMINI_API_KEY: {'SET' if os.environ.get('GEMINI_API_KEY') else 'NOT SET'}")
logger.info(f"Log file: {LOG_FILE}")

async def analyze_youtube_video(youtube_url: str, prompt: str) -> dict:
    """Analyze a YouTube video using Google Gemini API"""
    logger.info(f"analyze_youtube_video called with URL: {youtube_url}")
    
    # Check for GEMINI_API_KEY
    api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        logger.error("GEMINI_API_KEY not found in environment")
        return {
            "error": "GEMINI_API_KEY environment variable not found. Get your API key at: https://aistudio.google.com/apikey"
        }
    
    # Check if google-generativeai is installed
    try:
        import google.genai as genai  
        from google.genai.types import Part 

        client = genai.Client()

    except ImportError as e:
        logger.error(f"Failed to import google.genai: {e}")
        return {
            "error": "google-genai is not installed. Install it using: pip install google-genai"
        }
    
    video = Part.from_uri(  
        file_uri=youtube_url,  
        mime_type="video/mp4",  
    )  
    try:
        response = client.models.generate_content(
            model="gemini-2.5-pro",
            contents=[
                video,  
                prompt
            ]
        )

        return {
            "response": response.text
        }
        
    except Exception as e:
        logger.error(f"Error analyzing video: {str(e)}")
        logger.error(traceback.format_exc())
        return {
            "error": f"Error analyzing video: {str(e)}"
        }

class MCPServer:
    def __init__(self):
        self.methods = {
            "initialize": self.handle_initialize,
            "tools/list": self.handle_tools_list,
            "tools/call": self.handle_tools_call,
        }
    
    async def handle_initialize(self, params: dict) -> dict:
        return {
            "protocolVersion": "2025-06-18",
            "capabilities": {
                "tools": {}
            },
            "serverInfo": {
                "name": "ask-youtube-transcript",
                "version": "1.0.0"
            }
        }
    
    async def handle_tools_list(self, params: dict) -> dict:
        return {
            "tools": [
                {
                    "name": "analyze_youtube",
                    "description": "Analyze a YouTube video's transcript and visual content using Gemini API",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "youtube_url": {
                                "type": "string",
                                "description": "The YouTube URL to analyze"
                            },
                            "prompt": {
                                "type": "string",
                                "description": "The analysis prompt/question about the video"
                            }
                        },
                        "required": ["youtube_url", "prompt"]
                    }
                }
            ]
        }
    
    async def handle_tools_call(self, params: dict) -> dict:
        tool_name = params.get("name")
        arguments = params.get("arguments", {})
        
        if tool_name == "analyze_youtube":
            youtube_url = arguments.get("youtube_url")
            prompt = arguments.get("prompt")
            
            if not youtube_url or not prompt:
                return {
                    "content": [
                        {
                            "type": "text",
                            "text": "Error: Both youtube_url and prompt are required"
                        }
                    ]
                }
            
            result = await analyze_youtube_video(youtube_url, prompt)
            
            if "error" in result:
                return {
                    "content": [
                        {
                            "type": "text",
                            "text": f"Error: {result['error']}"
                        }
                    ]
                }
            else:
                return {
                    "content": [
                        {
                            "type": "text",
                            "text": result["response"]
                        }
                    ]
                }
        
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"Unknown tool: {tool_name}"
                }
            ]
        }
    
    async def handle_request(self, request: dict) -> dict:
        method = request.get("method")
        params = request.get("params", {})
        request_id = request.get("id")
        
        logger.debug(f"Received request: {json.dumps(request)}")
        
        if method in self.methods:
            try:
                result = await self.methods[method](params)
                response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": result
                }
                logger.debug(f"Sending response: {json.dumps(response)}")
                return response
            except Exception as e:
                logger.error(f"Error handling method {method}: {str(e)}")
                logger.error(traceback.format_exc())
                error_response = {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {
                        "code": -32603,
                        "message": str(e)
                    }
                }
                logger.debug(f"Sending error response: {json.dumps(error_response)}")
                return error_response
        else:
            logger.warning(f"Method not found: {method}")
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            }
    
    async def run(self):
        logger.info("MCP server run() started")
        while True:
            try:
                # Read a line from stdin
                logger.debug("Waiting for input from stdin...")
                line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
                if not line:
                    logger.info("EOF received, shutting down")
                    break
                
                logger.debug(f"Received line: {line.strip()}")
                
                # Parse the JSON-RPC request
                request = json.loads(line.strip())
                
                # Handle the request
                response = await self.handle_request(request)
                
                # Send the response
                response_str = json.dumps(response)
                logger.debug(f"Writing response to stdout: {response_str}")
                print(response_str)
                sys.stdout.flush()
                
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON received: {e}")
                logger.error(f"Line was: {line.strip() if 'line' in locals() else 'No line'}")
                continue
            except Exception as e:
                logger.error(f"Server error: {e}")
                logger.error(traceback.format_exc())

async def main():
    try:
        logger.info("Starting MCP server main()")
        server = MCPServer()
        await server.run()
    except Exception as e:
        logger.error(f"Fatal error in main: {e}")
        logger.error(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server interrupted by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        logger.error(traceback.format_exc())
        sys.exit(1)