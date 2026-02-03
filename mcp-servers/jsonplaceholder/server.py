#!/usr/bin/env python3
"""
JSONPlaceholder MCP Server
An HTTP-based MCP server that exposes JSONPlaceholder API as MCP tools.
"""

import asyncio
import json
from typing import Any
from urllib import request, error
from mcp.server import Server
from mcp.types import TextContent, Tool
from mcp.server.stdio import stdio_server

BASE_URL = "https://jsonplaceholder.typicode.com"

# Tool definitions
TOOLS = [
    Tool(
        name="get_posts",
        description="Get all posts from JSONPlaceholder",
        inputSchema={"type": "object", "properties": {}}
    ),
    Tool(
        name="get_post",
        description="Get a specific post by ID",
        inputSchema={
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "Post ID"}
            },
            "required": ["id"]
        }
    ),
    Tool(
        name="get_comments",
        description="Get comments for a specific post",
        inputSchema={
            "type": "object",
            "properties": {
                "post_id": {"type": "integer", "description": "Post ID to get comments for"}
            },
            "required": ["post_id"]
        }
    ),
    Tool(
        name="get_users",
        description="Get all users from JSONPlaceholder",
        inputSchema={"type": "object", "properties": {}}
    ),
    Tool(
        name="get_user",
        description="Get a specific user by ID",
        inputSchema={
            "type": "object",
            "properties": {
                "id": {"type": "integer", "description": "User ID"}
            },
            "required": ["id"]
        }
    ),
    Tool(
        name="get_todos",
        description="Get all todos from JSONPlaceholder",
        inputSchema={
            "type": "object",
            "properties": {
                "user_id": {"type": "integer", "description": "Optional user ID to filter todos"}
            }
        }
    ),
    Tool(
        name="get_albums",
        description="Get all albums from JSONPlaceholder",
        inputSchema={
            "type": "object",
            "properties": {
                "user_id": {"type": "integer", "description": "Optional user ID to filter albums"}
            }
        }
    ),
    Tool(
        name="get_photos",
        description="Get photos from a specific album",
        inputSchema={
            "type": "object",
            "properties": {
                "album_id": {"type": "integer", "description": "Album ID to get photos from"}
            },
            "required": ["album_id"]
        }
    ),
]


async def fetch_json(url: str) -> Any:
    """Fetch JSON data from URL."""
    try:
        with request.urlopen(url, timeout=10) as response:
            return json.loads(response.read().decode('utf-8'))
    except error.HTTPError as e:
        return {"error": f"HTTP Error {e.code}: {e.reason}"}
    except Exception as e:
        return {"error": f"Request failed: {str(e)}"}


async def handle_get_posts() -> str:
    """Handle get_posts tool."""
    data = await fetch_json(f"{BASE_URL}/posts")
    return json.dumps(data, indent=2)


async def handle_get_post(post_id: int) -> str:
    """Handle get_post tool."""
    data = await fetch_json(f"{BASE_URL}/posts/{post_id}")
    return json.dumps(data, indent=2)


async def handle_get_comments(post_id: int) -> str:
    """Handle get_comments tool."""
    data = await fetch_json(f"{BASE_URL}/posts/{post_id}/comments")
    return json.dumps(data, indent=2)


async def handle_get_users() -> str:
    """Handle get_users tool."""
    data = await fetch_json(f"{BASE_URL}/users")
    return json.dumps(data, indent=2)


async def handle_get_user(user_id: int) -> str:
    """Handle get_user tool."""
    data = await fetch_json(f"{BASE_URL}/users/{user_id}")
    return json.dumps(data, indent=2)


async def handle_get_todos(user_id: int = None) -> str:
    """Handle get_todos tool."""
    if user_id:
        data = await fetch_json(f"{BASE_URL}/users/{user_id}/todos")
    else:
        data = await fetch_json(f"{BASE_URL}/todos")
    return json.dumps(data, indent=2)


async def handle_get_albums(user_id: int = None) -> str:
    """Handle get_albums tool."""
    if user_id:
        data = await fetch_json(f"{BASE_URL}/users/{user_id}/albums")
    else:
        data = await fetch_json(f"{BASE_URL}/albums")
    return json.dumps(data, indent=2)


async def handle_get_photos(album_id: int) -> str:
    """Handle get_photos tool."""
    data = await fetch_json(f"{BASE_URL}/albums/{album_id}/photos")
    return json.dumps(data, indent=2)


async def serve():
    """Main server function."""
    server = Server("jsonplaceholder-mcp")
    
    @server.list_tools()
    async def list_tools() -> list:
        return TOOLS
    
    @server.call_tool()
    async def call_tool(name: str, arguments: dict) -> list:
        try:
            if name == "get_posts":
                result = await handle_get_posts()
            elif name == "get_post":
                result = await handle_get_post(arguments["id"])
            elif name == "get_comments":
                result = await handle_get_comments(arguments["post_id"])
            elif name == "get_users":
                result = await handle_get_users()
            elif name == "get_user":
                result = await handle_get_user(arguments["id"])
            elif name == "get_todos":
                result = await handle_get_todos(arguments.get("user_id"))
            elif name == "get_albums":
                result = await handle_get_albums(arguments.get("user_id"))
            elif name == "get_photos":
                result = await handle_get_photos(arguments["album_id"])
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
