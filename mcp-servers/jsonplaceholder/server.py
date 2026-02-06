"""JSONPlaceholder MCP Server.

Exposes JSONPlaceholder REST API (https://jsonplaceholder.typicode.com/) as MCP tools.
Provides 8 tools for accessing posts, users, comments, todos, albums, and photos.
"""

from __future__ import annotations

import os
from typing import Any, Literal

import httpx
from fastmcp import FastMCP

# Transport type for FastMCP
Transport = Literal["stdio", "sse", "http", "streamable-http"]

# Initialize FastMCP server
mcp = FastMCP(
    name="jsonplaceholder-mcp",
)

BASE_URL = "https://jsonplaceholder.typicode.com"
TIMEOUT = 30.0


async def _fetch(endpoint: str, params: dict[str, Any] | None = None) -> Any:
    """Fetch data from JSONPlaceholder API."""
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        response = await client.get(f"{BASE_URL}{endpoint}", params=params)
        response.raise_for_status()
        return response.json()


@mcp.tool()
async def get_posts() -> list[dict[str, Any]]:
    """Get all blog posts from JSONPlaceholder API.

    Returns a list of 100 posts, each containing:
    - id: Post ID
    - userId: Author's user ID
    - title: Post title
    - body: Post content
    """
    return await _fetch("/posts")


@mcp.tool()
async def get_post(id: int) -> dict[str, Any]:
    """Get a specific blog post by ID.

    Args:
        id: The post ID (1-100)

    Returns:
        Post object with id, userId, title, and body
    """
    return await _fetch(f"/posts/{id}")


@mcp.tool()
async def get_comments(post_id: int) -> list[dict[str, Any]]:
    """Get all comments for a specific post.

    Args:
        post_id: The post ID to get comments for

    Returns:
        List of comments, each containing:
        - id: Comment ID
        - postId: Parent post ID
        - name: Comment title/subject
        - email: Commenter's email
        - body: Comment content
    """
    return await _fetch("/comments", params={"postId": post_id})


@mcp.tool()
async def get_users() -> list[dict[str, Any]]:
    """Get all users from JSONPlaceholder API.

    Returns a list of 10 users, each containing:
    - id: User ID
    - name: Full name
    - username: Username
    - email: Email address
    - address: Address object with street, city, zipcode, geo coordinates
    - phone: Phone number
    - website: Website URL
    - company: Company object with name, catchPhrase, bs
    """
    return await _fetch("/users")


@mcp.tool()
async def get_user(id: int) -> dict[str, Any]:
    """Get a specific user by ID.

    Args:
        id: The user ID (1-10)

    Returns:
        User object with full profile information
    """
    return await _fetch(f"/users/{id}")


@mcp.tool()
async def get_todos(user_id: int | None = None) -> list[dict[str, Any]]:
    """Get todos, optionally filtered by user.

    Args:
        user_id: Optional user ID to filter todos (1-10)

    Returns:
        List of todos, each containing:
        - id: Todo ID
        - userId: Owner's user ID
        - title: Todo title
        - completed: Boolean completion status
    """
    params = {"userId": user_id} if user_id else None
    return await _fetch("/todos", params=params)


@mcp.tool()
async def get_albums(user_id: int | None = None) -> list[dict[str, Any]]:
    """Get albums, optionally filtered by user.

    Args:
        user_id: Optional user ID to filter albums (1-10)

    Returns:
        List of albums, each containing:
        - id: Album ID
        - userId: Owner's user ID
        - title: Album title
    """
    params = {"userId": user_id} if user_id else None
    return await _fetch("/albums", params=params)


@mcp.tool()
async def get_photos(album_id: int) -> list[dict[str, Any]]:
    """Get all photos from a specific album.

    Args:
        album_id: The album ID to get photos from

    Returns:
        List of photos, each containing:
        - id: Photo ID
        - albumId: Parent album ID
        - title: Photo title
        - url: Full-size image URL
        - thumbnailUrl: Thumbnail image URL
    """
    return await _fetch("/photos", params={"albumId": album_id})


if __name__ == "__main__":
    transport: Transport = "streamable-http"
    transport_env = os.getenv("MCP_TRANSPORT", "streamable-http")
    if transport_env in ("stdio", "sse", "http", "streamable-http"):
        transport = transport_env  # type: ignore[assignment]
    port = int(os.getenv("MCP_PORT", "8001"))
    host = os.getenv("MCP_HOST", "0.0.0.0")  # noqa: S104 - bind all interfaces for Docker

    mcp.run(transport=transport, host=host, port=port)
