#!/usr/bin/env python3
"""
Filesystem MCP Server (Read-Only)
A stdio-based MCP server providing read-only filesystem operations.
"""

import asyncio
import json
import os
from pathlib import Path
from typing import Any
from mcp.server import Server
from mcp.types import TextContent, Tool
from mcp.server.stdio import stdio_server

# Read-only base path (mounted in Docker)
BASE_PATH = Path(os.environ.get("MCP_BASE_PATH", "/home"))

# Tool definitions
TOOLS = [
    Tool(
        name="list_directory",
        description="List contents of a directory",
        inputSchema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Directory path relative to base (default: root)",
                    "default": "."
                }
            }
        }
    ),
    Tool(
        name="read_file",
        description="Read contents of a file",
        inputSchema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "File path to read"
                }
            },
            "required": ["path"]
        }
    ),
    Tool(
        name="get_file_info",
        description="Get metadata about a file or directory",
        inputSchema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to get info for"
                }
            },
            "required": ["path"]
        }
    ),
]


def resolve_path(path: str) -> Path:
    """Resolve path relative to base, ensuring it stays within base."""
    target = (BASE_PATH / path).resolve()
    # Security: ensure we don't escape base path
    try:
        target.relative_to(BASE_PATH.resolve())
    except ValueError:
        raise ValueError(f"Access denied: {path} is outside allowed directory")
    return target


async def handle_list_directory(path: str = ".") -> str:
    """Handle list_directory tool."""
    try:
        target = resolve_path(path)
        if not target.exists():
            return json.dumps({"error": f"Path does not exist: {path}"})
        if not target.is_dir():
            return json.dumps({"error": f"Not a directory: {path}"})
        
        entries = []
        for item in target.iterdir():
            stat = item.stat()
            entries.append({
                "name": item.name,
                "type": "directory" if item.is_dir() else "file",
                "size": stat.st_size if item.is_file() else None,
                "modified": stat.st_mtime
            })
        
        return json.dumps({
            "path": str(target.relative_to(BASE_PATH)),
            "entries": entries
        }, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e)})


async def handle_read_file(path: str) -> str:
    """Handle read_file tool."""
    try:
        target = resolve_path(path)
        if not target.exists():
            return json.dumps({"error": f"File does not exist: {path}"})
        if target.is_dir():
            return json.dumps({"error": f"Path is a directory: {path}"})
        
        # Security: limit file size to 1MB
        stat = target.stat()
        if stat.st_size > 1024 * 1024:
            return json.dumps({"error": "File too large (max 1MB)"})
        
        # Read as text
        content = target.read_text(encoding='utf-8', errors='replace')
        
        return json.dumps({
            "path": str(target.relative_to(BASE_PATH)),
            "size": stat.st_size,
            "content": content
        }, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e)})


async def handle_get_file_info(path: str) -> str:
    """Handle get_file_info tool."""
    try:
        target = resolve_path(path)
        if not target.exists():
            return json.dumps({"error": f"Path does not exist: {path}"})
        
        stat = target.stat()
        
        return json.dumps({
            "path": str(target.relative_to(BASE_PATH)),
            "exists": True,
            "type": "directory" if target.is_dir() else "file",
            "size": stat.st_size,
            "permissions": oct(stat.st_mode)[-3:],
            "modified": stat.st_mtime,
            "accessed": stat.st_atime
        }, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e)})


async def serve():
    """Main server function."""
    server = Server("filesystem-mcp")
    
    @server.list_tools()
    async def list_tools() -> list:
        return TOOLS
    
    @server.call_tool()
    async def call_tool(name: str, arguments: dict) -> list:
        try:
            if name == "list_directory":
                result = await handle_list_directory(arguments.get("path", "."))
            elif name == "read_file":
                result = await handle_read_file(arguments["path"])
            elif name == "get_file_info":
                result = await handle_get_file_info(arguments["path"])
            else:
                return [TextContent(type="text", text=f"Unknown tool: {name}")]
            
            return [TextContent(type="text", text=result)]
        except Exception as e:
            return [TextContent(type="text", text=f"Error: {str(e)}")]
    
    options = server.create_initialization_options()
    async with stdio_server(server, options) as (read_stream, write_stream):
        await server.run(read_stream, write_stream, options)


if __name__ == "__main__":
    asyncio.run(serve())
