#!/usr/bin/env python3
import os
import sys

# Immediately log to stderr so Claude Desktop captures it
print(f"Starting with Python: {sys.executable}", file=sys.stderr)
print(f"Python version: {sys.version}", file=sys.stderr)
print(f"Python path: {sys.path}", file=sys.stderr)
print(f"PATH env: {os.environ.get('PATH', 'NOT SET')}", file=sys.stderr)

import logging
from pathlib import Path
from datetime import datetime
from mcp.server.fastmcp import FastMCP

# Set up logging EXACTLY like the working server
def setup_logging(
    log_level: str = "INFO",
    log_file: str = None,
    log_dir: str = None,
    log_to_stderr: bool = True
) -> logging.Logger:
    """Set up logging configuration."""
    # Create logger
    logger = logging.getLogger("ask-youtube")
    logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))
    
    # Remove existing handlers
    logger.handlers.clear()
    
    # Format for log messages
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Add stderr handler (required for MCP - must use stderr not stdout)
    if log_to_stderr:
        stderr_handler = logging.StreamHandler(sys.stderr)
        stderr_handler.setFormatter(formatter)
        stderr_handler.setLevel(getattr(logging, log_level.upper(), logging.INFO))
        logger.addHandler(stderr_handler)
    
    # Add file handler if specified
    if log_file or log_dir:
        if log_file:
            file_path = Path(log_file)
        else:
            # Use log_dir with timestamp
            log_dir_path = Path(log_dir) if log_dir else Path("logs")
            log_dir_path.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            file_path = log_dir_path / f"ask_youtube_transcript_{timestamp}.log"
        
        file_handler = logging.FileHandler(file_path)
        file_handler.setFormatter(formatter)
        file_handler.setLevel(logging.DEBUG)  # File gets all levels
        logger.addHandler(file_handler)
        
        # Log the log file location (to stderr only)
        if log_to_stderr:
            logger.info(f"Logging to file: {file_path}")
    
    return logger

# Set up logging
log_level = os.getenv("YOUTUBE_TRANSCRIPT_LOG_LEVEL", "INFO")
log_file = os.getenv("YOUTUBE_TRANSCRIPT_LOG_FILE")
log_dir = os.getenv("YOUTUBE_TRANSCRIPT_LOG_DIR", os.path.expanduser("~/Library/Application Support/Claude/MCP/logs"))
logger = setup_logging(log_level, log_file, log_dir)

logger.info("Starting ask-youtube MCP server")
logger.info(f"Python: {sys.executable}")
logger.info(f"Version: {sys.version}")
logger.info(f"CWD: {os.getcwd()}")
logger.info(f"GEMINI_API_KEY: {'SET' if os.environ.get('GEMINI_API_KEY') else 'NOT SET'}")

# Create MCP server
mcp = FastMCP(
    name="ask-youtube",
    version="1.0.0",
    description="Analyze YouTube videos using Gemini API"
)

@mcp.tool()
async def analyze_youtube(youtube_url: str, prompt: str) -> dict:
    """Analyze a YouTube video's transcript and visual content using Gemini API.
    
    Args:
        youtube_url: The YouTube URL to analyze
        prompt: The analysis prompt/question about the video
        
    Returns:
        Dictionary with the analysis response or error
    """
    logger.info(f"analyze_youtube called with URL: {youtube_url}")
    
    # Check for GEMINI_API_KEY
    api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        logger.error("GEMINI_API_KEY not found in environment")
        return {
            "error": "GEMINI_API_KEY not configured. Please run install_mcp.sh to set up your API key."
        }
    
    # Check if google-genai is installed
    try:
        import google.genai as genai  
        from google.genai.types import Part 
        
        client = genai.Client(api_key=api_key)
        
    except ImportError as e:
        logger.error(f"Failed to import google.genai: {e}")
        return {
            "error": "google-genai is not installed. Install it using: pip install google-genai"
        }
    
    try:
        video = Part.from_uri(  
            file_uri=youtube_url,  
            mime_type="video/mp4",  
        )
        
        response = client.models.generate_content(
            model="gemini-2.5-pro",
            contents=[
                video,  
                prompt
            ]
        )
        
        logger.info("Successfully analyzed video")
        return {
            "response": response.text
        }
        
    except Exception as e:
        logger.error(f"Error analyzing video: {str(e)}")
        return {
            "error": f"Error analyzing video: {str(e)}"
        }

def run_stdio():
    """Run MCP server with stdio transport."""
    logger.info("Starting MCP server in stdio mode")
    logger.info(f"Log level: {log_level}, Log directory: {log_dir}")
    # FastMCP handles all the stdio setup internally
    mcp.run(transport="stdio")

if __name__ == "__main__":
    run_stdio()