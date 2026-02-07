# MCP Gateway Demo Specification

## 1. Overview

This document describes the complete specification for a Model Context Protocol (MCP) Gateway demo. The demo showcases:

- **AgentGateway** as the central MCP gateway (https://agentgateway.dev/)
- **Path-based routing** with multiple distinct MCP routes on a single port
- **Public routes** proxying to remote MCP servers (no authentication)
- **OpenAPI-to-MCP translation** automatically exposing REST APIs (Swagger Petstore) as MCP tools
- **Protected routes** with OAuth 2.1 + DCR via a local Duende IdentityServer
- **Tool multiplexing** combining multiple backends through a single `/mixed` route
- **Admin UI** for gateway monitoring and management

## 2. Architecture Diagram

```
                                    +-----------------------------+
                                    |   Desktop MCP Clients       |
                                    |   (OpenCode / Inspector)    |
                                    +-------------+---------------+
                                                  |
                                                  | MCP Protocol
                                                  v
                              +---------------------------------------+
                              |        Nginx (localhost:8080)         |
                              |                                       |
                              |  gateway.localhost    -> MCP routes   |
                              |  gateway-ui.localhost -> Admin UI     |
                              |  idp.localhost        -> IdP          |
                              |  inspector.localhost  -> Inspector    |
                              +-------------------+-------------------+
                                                  |
                    +-----------------------------+-----------------------------+
                    |                                                           |
                    v                                                           v
          +-------------------+                                     +-------------------+
          |   AgentGateway    |                                     | IdentityServer    |
          |   Port 3000 (MCP) |                                     | Port 5001         |
          |   Port 3001 (UI)  |                                     +-------------------+
          +--------+----------+
                   |
    +--------------+--------------+
    |  Public Routes (no auth)    |
    |                             |
    |  /context7   -> Context7    |
    |  /travel     -> Kismet      |
    |  /learn      -> MS Learn    |
    |  /petstore   -> Petstore    |
    |    (OpenAPI -> MCP auto)    |
    +--------------+--------------+
    |  Protected Routes (OAuth)   |
    |                             |
    |  /placeholder -> :8001      |
    |  /weather     -> :8002      |
    |  /mixed       -> :8001+8002 |
    +-----------------------------+
          |                           |
          v                           v
+------------------+       +------------------+
| JSONPlaceholder  |       | Weather MCP      |
| MCP Server       |       | Server           |
| Port: 8001       |       | Port: 8002       |
+------------------+       +------------------+
```

## 3. Components

### 3.1 MCP Gateway (AgentGateway)

**Purpose**: Central management point for all MCP services with path-based routing
**MCP Endpoint**: http://gateway.localhost:8080 (via nginx) or http://localhost:3000 (direct)
**Admin UI**: http://gateway-ui.localhost:8080 (via nginx) or http://localhost:3001 (direct)

**Features**:
- Path-based MCP routing (6 routes on a single listener)
- Remote MCP server proxying (Context7, Kismet Travel, Microsoft Learn)
- Local MCP backend multiplexing (JSONPlaceholder, Weather)
- OAuth 2.1 authentication with DCR on protected routes
- Built-in admin UI via `config.adminAddr`
- SSE and Streamable HTTP transport support
- CORS support per route

**Configuration File**: `gateway/config.yaml`

### 3.2 Local IdentityServer (IdP)

**URL**: http://idp.localhost:8080 (via nginx) or http://localhost:5001 (direct)
**Docker Internal URL**: http://idp:5000

**Test Users**:
- `alice` / `alice` (Alice Smith)
- `bob` / `bob` (Bob Smith)

**Features**:
- Dynamic Client Registration (DCR) enabled
- Authorization Code + PKCE flow
- OpenID Connect with profile claims

**Scopes**:
- `openid` - OpenID Connect
- `profile` - User profile information
- `mcp:tools` - MCP tools access

**OAuth Endpoints** (via nginx):
- Discovery: `http://idp.localhost:8080/.well-known/openid-configuration`
- Authorization: `http://idp.localhost:8080/connect/authorize`
- Token: `http://idp.localhost:8080/connect/token`
- DCR: `http://idp.localhost:8080/connect/dcr`
- JWKS: `http://idp.localhost:8080/.well-known/openid-configuration/jwks`

### 3.3 HTTP MCP Server (JSONPlaceholder Integration)

**Purpose**: Expose JSONPlaceholder REST API as MCP tools
**Protocol**: HTTP/SSE
**Port**: 8001
**Gateway Route**: `/placeholder/mcp` (protected)

**Tools Provided** (prefixed as `jsonplaceholder_*`):
1. `get_posts` - List all posts
2. `get_post` - Get a specific post by ID
3. `get_comments` - Get comments for a post
4. `get_users` - List all users
5. `get_user` - Get a specific user by ID
6. `get_todos` - List todos
7. `get_albums` - List albums
8. `get_photos` - List photos from an album

### 3.4 HTTP MCP Server (Weather)

**Purpose**: Provide weather data via OpenWeatherMap API
**Protocol**: HTTP/SSE
**Port**: 8002
**Gateway Route**: `/weather/mcp` (protected)

**Tools Provided** (prefixed as `weather_*`):
1. `get_current` - Get current weather for a location
2. `get_forecast` - Get weather forecast for a location
3. `search_location` - Search for location coordinates

**API Integration**:
- Uses OpenWeatherMap API
- API key optional (uses mock data without key)
- Supports multiple units (metric, imperial, standard)

### 3.5 Remote MCP Servers (Public)

These are external MCP servers proxied through the gateway without authentication.

| Route | Remote Server | Description |
|-------|---------------|-------------|
| `/context7/mcp` | https://mcp.context7.com/mcp | Library documentation |
| `/travel/mcp` | https://mcp.kismet.travel/mcp | Travel planning |
| `/learn/mcp` | https://learn.microsoft.com/api/mcp | Microsoft Learn docs |

### 3.6 OpenAPI-to-MCP Translation (Public)

AgentGateway can automatically translate any REST API with an OpenAPI specification into MCP tools.
No custom MCP server code is required — the gateway reads the OpenAPI spec and exposes each operation as a tool.

| Route | OpenAPI Spec | API Host | Description |
|-------|-------------|----------|-------------|
| `/petstore/mcp` | https://petstore.swagger.io/v2/swagger.json | https://petstore.swagger.io | Swagger Petstore demo API |

**How it works**:
1. The gateway loads the OpenAPI spec at startup from the mounted `schema.file`
2. Each API operation (identified by `operationId`) becomes an MCP tool
3. Request/response schemas from the spec define tool input/output
4. When a tool is called, the gateway translates it to an HTTP request to the `host`
5. Tools are prefixed with the target name (e.g., `petstore_addPet`)

**Configuration**:
```yaml
- name: petstore
  openapi:
    schema:
      file: /etc/agentgateway/petstore-openapi.json  # Mounted OpenAPI spec
    host: https://petstore.swagger.io                # API server
```

See [AgentGateway OpenAPI docs](https://agentgateway.dev/docs/mcp/connect/openapi/) for details.

## 4. Gateway Configuration

The gateway is configured via `gateway/config.yaml`:

```yaml
config:
  adminAddr: "0.0.0.0:3001"

binds:
- port: 3000
  listeners:
  - routes:
    # Public - remote MCP servers and OpenAPI specs, no auth
    - name: context7
      matches:
      - path:
          pathPrefix: /context7
      backends:
      - mcp:
          targets:
          - name: context7
            mcp:
              host: https://mcp.context7.com/mcp
      policies:
        cors: { allowOrigins: ["*"], ... }

    # Protected - local backends, OAuth 2.1 + DCR
    - name: placeholder
      matches:
      - path:
          pathPrefix: /placeholder
      backends:
      - mcp:
          targets:
          - name: jsonplaceholder
            mcp:
              host: http://jsonplaceholder-mcp:8001/sse
      policies:
        mcpAuthentication:
          issuer: http://idp.localhost:8080
          audiences: [mcp-gateway]
          jwks:
            url: http://idp:5000/.well-known/openid-configuration/jwks
          resourceMetadata:
            resource: http://gateway.localhost:8080/placeholder
            authorization_servers:
              - http://idp.localhost:8080
          mode: strict
        cors: { allowOrigins: ["*"], ... }

    # Mixed - multiplexes both local backends, protected
    - name: mixed
      matches:
      - path:
          pathPrefix: /mixed
      backends:
      - mcp:
          targets:
          - name: jsonplaceholder
            mcp:
              host: http://jsonplaceholder-mcp:8001/sse
          - name: weather
            mcp:
              host: http://weather-mcp:8002/sse
      policies:
        mcpAuthentication: { ... }
        cors: { ... }
```

### Key Configuration Concepts

- **`config.adminAddr`**: Enables the built-in admin UI on a separate port
- **`matches.path.pathPrefix`**: Routes requests by URL path to different backends
- **`mcpAuthentication`**: Per-route OAuth 2.1 with DCR, validating JWTs from the IdP
- **`resourceMetadata`**: RFC 9728 Protected Resource Metadata, telling MCP clients where to authenticate
- **`mode: strict`**: Requires a valid token; public routes omit `mcpAuthentication` entirely

## 5. Nginx Routing

Nginx acts as a reverse proxy, routing by hostname:

| Hostname | Upstream | Purpose |
|----------|----------|---------|
| `gateway.localhost` | `mcp-gateway:3000` | MCP routes |
| `gateway-ui.localhost` | `mcp-gateway:3001` | Admin UI |
| `idp.localhost` | `idp:5000` | IdentityServer |
| `inspector.localhost` | `mcp-inspector:6274` | MCP Inspector |
| `jsonplaceholder.localhost` | `jsonplaceholder-mcp:8001` | Direct MCP access |
| `weather.localhost` | `weather-mcp:8002` | Direct MCP access |

All hostnames are served on port 8080 (mapped from container port 80).

## 6. Demo Flow

### Phase 1: Setup (Automated)

1. **Start Infrastructure**:
   ```bash
   ./scripts/start-demo.sh
   ```
   - Starts AgentGateway on port 3000 (MCP) + 3001 (Admin UI)
   - Starts IdentityServer on port 5001
   - Starts JSONPlaceholder MCP on port 8001
   - Starts Weather MCP on port 8002
   - Starts MCP Inspector on port 6274
   - Starts Nginx proxy on port 8080

2. **Verify Services**:
   - Gateway Admin UI: http://gateway-ui.localhost:8080
   - Nginx health: http://localhost:8080/health
   - IdP discovery: http://idp.localhost:8080/.well-known/openid-configuration

### Phase 2: Test Public Routes

1. Open MCP Inspector at http://inspector.localhost:8080
2. Set server URL: `http://gateway.localhost:8080/context7/mcp`
3. Select transport: Streamable HTTP
4. Connect — no authentication required
5. Browse tools from Context7

### Phase 2b: Test OpenAPI-to-MCP (Petstore)

1. Set server URL: `http://gateway.localhost:8080/petstore/mcp`
2. Select transport: Streamable HTTP
3. Connect — no authentication required
4. Browse auto-generated tools from the Swagger Petstore OpenAPI spec
5. Every REST endpoint (pet, store, user operations) appears as an MCP tool

### Phase 3: Test Protected Routes

1. Set server URL: `http://gateway.localhost:8080/placeholder/mcp`
2. Connect — gateway returns `401` with resource metadata
3. Client performs OAuth 2.1 flow:
   - Discovers authorization server from `resourceMetadata.authorization_servers`
   - Registers via DCR at `/connect/dcr`
   - Redirects to IdentityServer for login
   - User authenticates (alice/alice or bob/bob)
   - Client receives access token
4. Subsequent requests include Bearer token
5. Browse JSONPlaceholder tools

### Phase 4: Test Mixed Route

1. Set server URL: `http://gateway.localhost:8080/mixed/mcp`
2. Authenticate as above
3. Browse all 11 tools from both backends

## 7. Tool Naming Convention

AgentGateway automatically prefixes tools with their backend name:

| Backend | Original Tool | Exposed Tool |
|---------|--------------|--------------|
| jsonplaceholder | get_posts | jsonplaceholder_get_posts |
| jsonplaceholder | get_users | jsonplaceholder_get_users |
| weather | get_current | weather_get_current |
| weather | get_forecast | weather_get_forecast |

This prevents naming conflicts when multiplexing multiple backends on the `/mixed` route.

## 8. Security Considerations

### 8.1 OAuth Flow (Protected Routes)
- Uses Authorization Code + PKCE (secure for public clients)
- Dynamic Client Registration (DCR) supported
- Short-lived access tokens from local IdentityServer
- Gateway validates tokens via JWKS endpoint
- `mode: strict` rejects unauthenticated requests

### 8.2 Public Routes
- No authentication required
- Traffic proxied directly to remote MCP servers or translated from OpenAPI specs
- CORS configured to allow all origins (demo)

### 8.3 Backend Security
- MCP servers have no authentication (internal Docker network only)
- Weather MCP uses API key for external API access
- Both only accessible via gateway or direct port (network isolation)

### 8.4 Demo Security Warnings
- Test users with simple passwords (alice/alice, bob/bob)
- Local IdentityServer uses development signing keys
- Not suitable for production use

## 9. Client Configuration Guides

### 9.1 MCP Inspector

1. Open http://inspector.localhost:8080
2. Enter a gateway route URL (e.g., `http://gateway.localhost:8080/context7/mcp`)
3. Select transport: Streamable HTTP
4. Connect and interact with tools

### 9.2 OpenCode Desktop

**Documentation**: https://docs.opencode.ai/clients/mcp

```json
{
  "mcpServers": {
    "public-context7": {
      "url": "http://gateway.localhost:8080/context7/mcp",
      "transport": "streamable-http"
    },
    "protected-placeholder": {
      "url": "http://gateway.localhost:8080/placeholder/mcp",
      "transport": "streamable-http"
    }
  }
}
```

## 10. Troubleshooting

### Common Issues

1. **Gateway not starting**: Check `docker compose logs mcp-gateway`
2. **OAuth errors**: Verify IdP is healthy at http://idp.localhost:8080/.well-known/openid-configuration
3. **Tools not visible**: Ensure MCP servers are running (`docker compose ps`)
4. **`*.localhost` not resolving**: Most OS/browsers resolve `*.localhost` to `127.0.0.1`. If not, add entries to your hosts file.
5. **Admin UI not loading**: Verify `config.adminAddr` is set in `gateway/config.yaml` and port 3001 is exposed.

### Debug Commands

```bash
# Check all services
docker compose ps

# View gateway logs
docker compose logs mcp-gateway

# View MCP server logs
docker compose logs jsonplaceholder-mcp
docker compose logs weather-mcp

# Test MCP servers directly
curl http://localhost:8001/sse
curl http://localhost:8002/sse

# Test gateway health
curl http://localhost:8080/health

# View IdP configuration
curl http://idp.localhost:8080/.well-known/openid-configuration
```

## 11. References

- [AgentGateway Documentation](https://agentgateway.dev/)
- [AgentGateway Configuration Reference](https://agentgateway.dev/docs/local/latest/reference/configuration/)
- [Duende IdentityServer Documentation](https://docs.duendesoftware.com/)
- [JSONPlaceholder Guide](https://jsonplaceholder.typicode.com/guide/)
- [OpenWeatherMap API Documentation](https://openweathermap.org/api)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [MCP Inspector](https://github.com/modelcontextprotocol/inspector)
- [Swagger Petstore](https://petstore.swagger.io/) - Petstore demo API
- [AgentGateway OpenAPI-to-MCP](https://agentgateway.dev/docs/mcp/connect/openapi/) - OpenAPI backend docs
- [RFC 9728 - OAuth 2.0 Protected Resource Metadata](https://datatracker.ietf.org/doc/html/rfc9728)

---

**Document Version**: 3.0
**Last Updated**: 2026-02-07
**Status**: Updated with OpenAPI-to-MCP (Petstore) and path-based routing with public/protected routes
