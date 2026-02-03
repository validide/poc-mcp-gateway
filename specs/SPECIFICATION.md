# MCP Gateway Demo Specification

## 1. Overview

This document describes the complete specification for a Model Context Protocol (MCP) Gateway demo. The demo showcases:

- **IBM MCP Context Forge** as the central gateway
- **Duende Demo Server** for OAuth 2.1 authentication
- Two custom MCP backends:
  - HTTP-based MCP fetching data from JSONPlaceholder API
  - stdio-based Docker MCP for filesystem read-only operations
- A virtual server combining both backends with OAuth 2.1 security

## 2. Architecture Diagram

```
                                    +-----------------------------+
                                    |   OpenCode Desktop / VS     |
                                    |   Code / ChatGPT Desktop    |
                                    +-------------+---------------+
                                                  |
                                                  | Connect to Gateway
                                                  v
+-------------------+     OAuth 2.1          +----------------------------+
| Duende Demo Server| <--------------------> |    MCP Context Forge       |
| (demo.duendesoftware.com)                  |    Gateway (localhost:4444)|
+-------------------+                        +-------------+--------------+
                                                        |
                                        +---------------+---------------+
                                        |                               |
                                        v                               v
                              +------------------+           +------------------+
                              | HTTP MCP Server  |           | stdio MCP Server |
                              | (JSONPlaceholder)|           | (Docker-based    |
                              | Port: 8001       |           | Filesystem)      |
                              +------------------+           +------------------+
```

## 3. Components

### 3.1 MCP Gateway (IBM Context Forge)

**Purpose**: Central management point for all MCP services
**Endpoint**: http://localhost:4444
**Features Used**:
- MCP Server Registry
- Virtual Server Composition
- OAuth 2.1 Authentication Integration
- Admin UI for configuration

### 3.2 Duende Demo Server

**URL**: https://demo.duendesoftware.com/
**Client Configuration**:
- Client ID: `interactive.public`
- Grant Type: Authorization Code
- PKCE: Required
- Allowed Scopes: `api`, `openid`, `profile`, `email`, `offline_access`

**Why interactive.public?**
- No client secret required (suitable for SPAs and native apps)
- Supports Authorization Code flow with PKCE for security
- Easier demo setup without secret management

**OAuth Endpoints**:
- Discovery: `https://demo.duendesoftware.com/.well-known/openid-configuration`
- Authorization: `https://demo.duendesoftware.com/connect/authorize`
- Token: `https://demo.duendesoftware.com/connect/token`

### 3.3 HTTP MCP Server (JSONPlaceholder Integration)

**Purpose**: Expose JSONPlaceholder REST API as MCP tools
**Protocol**: HTTP/SSE
**Port**: 8001

**Tools Provided**:
1. `get_posts` - List all posts
2. `get_post` - Get a specific post by ID
3. `get_comments` - Get comments for a post
4. `get_users` - List all users
5. `get_user` - Get a specific user by ID
6. `get_todos` - List todos
7. `get_albums` - List albums
8. `get_photos` - List photos from an album

### 3.4 stdio MCP Server (Filesystem)

**Purpose**: Read-only filesystem operations for demo user
**Protocol**: stdio (via Docker)
**Implementation**: Python MCP server in Docker container

**Tools Provided**:
1. `list_directory` - List contents of a directory
2. `read_file` - Read contents of a file
3. `get_file_info` - Get metadata about a file/directory

**Security**:
- Read-only operations only
- Access restricted to containerized environment
- Mounts user home directory read-only

### 3.5 Virtual Server

**Purpose**: Combined interface exposing tools from both backends
**Authentication**: OAuth 2.1 required
**Endpoint**: http://localhost:4444/servers/{virtual-server-id}/mcp

**Combined Tools**:
- All JSONPlaceholder tools (8 tools)
- All Filesystem tools (3 tools)
- Total: 11 tools available after OAuth authentication

## 4. Demo Flow

### Phase 1: Setup (Automated via Script)

1. **Start Infrastructure**:
   ```bash
   ./start-demo.sh
   ```
   - Starts MCP Gateway container on port 4444
   - Starts HTTP MCP server container on port 8001
   - Builds and starts stdio MCP server container
   - Initializes gateway with default admin user

2. **Verify Services**:
   - Gateway health check: http://localhost:4444/health
   - HTTP MCP health: http://localhost:8001/health
   - Admin UI: http://localhost:4444/admin

### Phase 2: Backend Configuration

**Step 1: Register HTTP MCP Server**
- User logs into Admin UI
- Navigates to "Gateways" section
- Registers new MCP server:
  - Name: `jsonplaceholder-mcp`
  - URL: `http://host.docker.internal:8001/sse`
  - Protocol: SSE
- Gateway discovers 8 tools automatically

**Step 2: Register stdio MCP Server**
- Uses gateway's `translate` feature to expose stdio as SSE:
  ```bash
  python3 -m mcpgateway.translate \
    --stdio "docker run --rm -i mcp-filesystem-stdio" \
    --expose-sse \
    --port 8002
  ```
- Registers the translated server in gateway:
  - Name: `filesystem-mcp`
  - URL: `http://host.docker.internal:8002/sse`
- Gateway discovers 3 tools automatically

### Phase 3: Virtual Server Creation

**Step 3: Create Virtual Server**
- User navigates to "Servers" section in Admin UI
- Creates new virtual server:
  - Name: `demo-combined-server`
  - Description: "Combined JSONPlaceholder and Filesystem tools"
  - Associated Tools: [select all 11 tools from both backends]
- Server created with unique UUID

### Phase 4: OAuth Configuration

**Step 4: Configure OAuth 2.1**
- In Admin UI, navigate to virtual server settings
- Configure authentication:
  - Provider: `duende-demo`
  - Discovery URL: `https://demo.duendesoftware.com/.well-known/openid-configuration`
  - Client ID: `interactive.public`
  - Redirect URI: `http://localhost:4444/auth/callback`
  - Scopes: `openid profile email api`

**Step 5: Test OAuth Flow**
- Access virtual server endpoint: http://localhost:4444/servers/{uuid}/mcp
- Redirects to Duende login page
- User authenticates with demo credentials
- Redirects back to gateway with access token
- Tools now accessible with valid OAuth session

### Phase 5: Client Integration

**Step 6: Configure Desktop Client**
- Use MCP Inspector or configure in OpenCode Desktop/VS Code/ChatGPT Desktop
- Server URL: `http://localhost:4444/servers/{uuid}/mcp`
- Authentication: OAuth flow handled automatically

**Step 7: Test Integration**
- List available tools (should show all 11)
- Test JSONPlaceholder tool: `get_users`
- Test Filesystem tool: `list_directory`

## 5. Implementation Details

### 5.1 HTTP MCP Server Implementation

**Technology**: Python with FastMCP library
**File**: `mcp-servers/jsonplaceholder/server.py`

```python
# Key implementation points:
- Uses FastMCP framework
- HTTP transport on port 8001
- Fetches from https://jsonplaceholder.typicode.com/
- Returns structured JSON responses
- Error handling for API failures
```

### 5.2 stdio MCP Server Implementation

**Technology**: Python with FastMCP library
**File**: `mcp-servers/filesystem/server.py`

```python
# Key implementation points:
- Uses FastMCP framework
- stdio transport (reads/writes to stdin/stdout)
- Read-only operations only
- Containerized with Docker
- Mounts /home (read-only) for demo user
```

### 5.3 Docker Compose Configuration

**File**: `docker-compose.yml`

**Services**:
1. `mcp-gateway` - IBM Context Forge gateway
2. `jsonplaceholder-mcp` - HTTP MCP server
3. `filesystem-mcp` - stdio MCP server (via translate wrapper)

### 5.4 Startup Script

**File**: `start-demo.sh`

**Responsibilities**:
- Check Docker/Podman availability
- Create necessary directories
- Pull/build container images
- Start services in correct order
- Wait for health checks
- Display URLs and next steps
- Provide admin credentials

## 6. Security Considerations

### 6.1 OAuth Flow
- Uses Authorization Code + PKCE (secure for public clients)
- No client secret required (interactive.public)
- Short-lived access tokens from Duende demo
- Gateway validates tokens against Duende

### 6.2 Backend Security
- HTTP MCP server has no authentication (internal only)
- Filesystem MCP is read-only and containerized
- Both only accessible via gateway (network isolation)

### 6.3 Virtual Server Security
- OAuth required for all tool access
- User identity verified via Duende
- Session management handled by gateway

## 7. Client Configuration Guides

### 7.1 OpenCode Desktop

**Documentation**: https://docs.opencode.ai/clients/mcp

**Configuration**:
```json
{
  "mcpServers": {
    "demo-gateway": {
      "url": "http://localhost:4444/servers/{uuid}/mcp",
      "oauth": {
        "enabled": true,
        "provider": "duende"
      }
    }
  }
}
```

### 7.2 VS Code with Cline/Roo Code

**Documentation**: https://github.com/cline/cline#model-context-protocol-mcp

**Configuration**:
- Use MCP settings in VS Code
- Add server URL with OAuth support

### 7.3 ChatGPT Desktop

**Documentation**: https://help.openai.com/en/articles/10175700-mcp

**Configuration**:
- Navigate to Settings > MCP
- Add custom server endpoint
- Complete OAuth flow

## 8. Demo Script

### Pre-requisites Check
```bash
# Check Docker
 docker ps > /dev/null 2>&1 || { echo "Docker not running"; exit 1; }

# Check ports
lsof -i :4444 > /dev/null 2>&1 && { echo "Port 4444 in use"; exit 1; }
lsof -i :8001 > /dev/null 2>&1 && { echo "Port 8001 in use"; exit 1; }
```

### Startup Sequence
```bash
#!/bin/bash
echo "=== MCP Gateway Demo Startup ==="
echo ""

# 1. Start gateway
echo "[1/5] Starting MCP Gateway..."
docker compose up -d mcp-gateway
sleep 5

# 2. Start HTTP MCP
echo "[2/5] Starting JSONPlaceholder MCP Server..."
docker compose up -d jsonplaceholder-mcp
sleep 3

# 3. Build filesystem MCP
echo "[3/5] Building Filesystem MCP Server..."
docker compose build filesystem-mcp

# 4. Start translate wrapper
echo "[4/5] Starting stdio-to-SSE translator..."
docker compose up -d filesystem-translate

# 5. Health checks
echo "[5/5] Waiting for services..."
./scripts/wait-for-healthy.sh

echo ""
echo "=== Demo Ready ==="
echo "Gateway Admin UI: http://localhost:4444/admin"
echo "Admin Email: admin@demo.local"
echo "Admin Password: demopass123"
echo ""
echo "Next Steps:"
echo "1. Open http://localhost:4444/admin"
echo "2. Log in with credentials above"
echo "3. Follow the guided setup wizard"
echo ""
echo "Press Ctrl+C to stop all services"
docker compose logs -f
```

## 9. Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 4444 and 8001 are free
2. **Docker Network**: Use `host.docker.internal` for cross-container communication
3. **OAuth Redirect**: Ensure callback URL matches gateway configuration
4. **CORS Issues**: Gateway handles CORS, but verify client configuration

### Debug Commands

```bash
# Check gateway logs
docker compose logs mcp-gateway

# Check HTTP MCP logs
docker compose logs jsonplaceholder-mcp

# Test HTTP MCP directly
curl http://localhost:8001/tools

# Test gateway API
curl http://localhost:4444/health
```

## 10. References

- [MCP Context Forge Documentation](https://ibm.github.io/mcp-context-forge/)
- [Duende IdentityServer Documentation](https://docs.duendesoftware.com/)
- [JSONPlaceholder Guide](https://jsonplaceholder.typicode.com/guide/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [OpenCode MCP Client Docs](https://docs.opencode.ai/)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-03
**Status**: Specification Ready for Implementation