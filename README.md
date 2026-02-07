# MCP Gateway Demo

A complete demonstration of the Model Context Protocol (MCP) Gateway using AgentGateway, featuring path-based routing with public and OAuth 2.1 protected routes, a local Duende IdentityServer, and multiple MCP backends (local and remote).

## Overview

This demo showcases:
- **AgentGateway** as the central MCP gateway (https://agentgateway.dev/)
- **Path-based routing** with 6 distinct MCP routes on a single endpoint
- **Public routes** proxying to remote MCP servers (Context7, Kismet Travel, Microsoft Learn)
- **OpenAPI-to-MCP translation** automatically exposing the Swagger Petstore REST API as MCP tools
- **Protected routes** with OAuth 2.1 + DCR for local MCP backends (JSONPlaceholder, Weather)
- **Tool multiplexing** combining multiple backends through a single `/mixed` route
- **Local Duende IdentityServer** for OAuth 2.1 authentication (with test users alice/bob)
- **Admin UI** for gateway monitoring and management

## Architecture

```
+---------------------------------------------------------------+
|                     Desktop MCP Clients                        |
|              (OpenCode Desktop / MCP Inspector)                |
+---------------------------+-----------------------------------+
                            |
                            | MCP Protocol (Streamable HTTP)
                            v
+---------------------------------------------------------------+
|                   Nginx (localhost:8080)                       |
|                                                                |
|  gateway.localhost     -> AgentGateway (MCP routes)            |
|  gateway-ui.localhost  -> AgentGateway Admin UI                |
|  idp.localhost         -> IdentityServer                       |
|  inspector.localhost   -> MCP Inspector                        |
+---------------------------+-----------------------------------+
                            |
        +-------------------+-------------------+
        |                                       |
        v                                       v
+------------------+                  +-------------------+
| AgentGateway     |                  | IdentityServer    |
| (Port 3000)      |                  | (Port 5001)       |
| (Admin: 3001)    |                  +-------------------+
+--------+---------+
         |
         +------ Public (no auth) ------+------------------+
         |               |              |                  |
         v               v              v                  |
  +------------+  +------------+  +-------------+          |
  | Context7   |  | Kismet     |  | Microsoft   |          |
  | (remote)   |  | Travel     |  | Learn       |          |
  |            |  | (remote)   |  | (remote)    |          |
  +------------+  +------------+  +-------------+          |
         |                                                 |
         v                                                 |
  +-------------------+                                    |
  | Swagger Petstore  |                                    |
  | (OpenAPI -> MCP)  |                                    |
  | (remote)          |                                    |
  +-------------------+                                    |
         |                                                 |
         +------ Protected (OAuth+DCR) ---+                |
         |                |               |                |
         v                v               v
  +------------------+  +------------------+
  | JSONPlaceholder  |  | Weather MCP      |
  | MCP Server       |  | Server           |
  | (Port 8001)      |  | (Port 8002)      |
  +------------------+  +------------------+
```

## Quick Start

### Prerequisites

- Docker Desktop or Docker Engine
- Docker Compose

### Start the Demo

```bash
# Using the start script
./scripts/start-demo.sh

# Or manually
docker compose up -d --build
```

### Access the Demo

#### Services (via nginx on port 8080)

| Service | URL |
|---------|-----|
| Gateway MCP | http://gateway.localhost:8080 |
| Gateway Admin UI | http://gateway-ui.localhost:8080 |
| IdentityServer | http://idp.localhost:8080 |
| MCP Inspector | http://inspector.localhost:8080 |
| JSONPlaceholder MCP | http://jsonplaceholder.localhost:8080 |
| Weather MCP | http://weather.localhost:8080 |

#### Direct Access

| Service | URL |
|---------|-----|
| Gateway MCP | http://localhost:3000 |
| Gateway Admin UI | http://localhost:3001 |
| IdentityServer | http://localhost:5001 |
| MCP Inspector | http://localhost:6274 |
| JSONPlaceholder MCP | http://localhost:8001 |
| Weather MCP | http://localhost:8002 |

## Gateway Routes

All routes are served through the gateway at `http://gateway.localhost:8080`.

### Public Routes (no authentication)

| Route | Path | Remote Target |
|-------|------|---------------|
| Context7 | `/context7/mcp` | https://mcp.context7.com/mcp |
| Kismet Travel | `/travel/mcp` | https://mcp.kismet.travel/mcp |
| Microsoft Learn | `/learn/mcp` | https://learn.microsoft.com/api/mcp |
| Swagger Petstore | `/petstore/mcp` | OpenAPI auto-translation from https://petstore.swagger.io |

### Protected Routes (OAuth 2.1 + DCR)

These routes require authentication via the local IdentityServer.

| Route | Path | Backend |
|-------|------|---------|
| JSONPlaceholder | `/placeholder/mcp` | jsonplaceholder-mcp:8001 |
| Weather | `/weather/mcp` | weather-mcp:8002 |
| Mixed | `/mixed/mcp` | JSONPlaceholder + Weather combined |

The `/mixed` route multiplexes both local backends, exposing all tools from both servers through a single endpoint.

## Configuration

### Gateway Configuration

The gateway is configured via `gateway/config.yaml` with path-based routing:

```yaml
config:
  adminAddr: "0.0.0.0:3001"

binds:
- port: 3000
  listeners:
  - routes:
    # Public - no auth, proxied to remote MCP servers or OpenAPI specs
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

    # Public - OpenAPI to MCP auto-translation
    - name: petstore
      matches:
      - path:
          pathPrefix: /petstore
      backends:
      - mcp:
          targets:
          - name: petstore
            openapi:
              schema:
                file: /etc/agentgateway/petstore-openapi.json
              host: https://petstore.swagger.io

    # Protected - OAuth 2.1 with DCR
    - name: placeholder
      matches:
      - path:
          pathPrefix: /placeholder
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
      backends:
      - mcp:
          targets:
          - name: jsonplaceholder
            mcp:
              host: http://jsonplaceholder-mcp:8001/sse
```

### Tool Naming

AgentGateway automatically prefixes tools with their backend name to avoid conflicts:
- `jsonplaceholder_get_posts`
- `jsonplaceholder_get_users`
- `weather_get_current`
- `weather_get_forecast`

## Testing with MCP Inspector

1. Open MCP Inspector at http://inspector.localhost:8080
2. Set server URL to a gateway route:
   - Public: `http://gateway.localhost:8080/context7/mcp`
   - Public (OpenAPI): `http://gateway.localhost:8080/petstore/mcp`
   - Protected: `http://gateway.localhost:8080/placeholder/mcp`
3. Select transport: Streamable HTTP
4. Connect and browse available tools

## Available Tools

### JSONPlaceholder Tools (8 tools) — via `/placeholder/mcp`

| Tool | Description | Parameters |
|------|-------------|------------|
| `jsonplaceholder_get_posts` | List all blog posts | None |
| `jsonplaceholder_get_post` | Get specific post by ID | `id` (integer) |
| `jsonplaceholder_get_comments` | Get comments for a post | `post_id` (integer) |
| `jsonplaceholder_get_users` | List all users | None |
| `jsonplaceholder_get_user` | Get specific user by ID | `id` (integer) |
| `jsonplaceholder_get_todos` | List all todos | `user_id` (integer, optional) |
| `jsonplaceholder_get_albums` | List all albums | `user_id` (integer, optional) |
| `jsonplaceholder_get_photos` | Get photos from album | `album_id` (integer) |

### Weather Tools (3 tools) — via `/weather/mcp`

| Tool | Description | Parameters |
|------|-------------|------------|
| `weather_get_current` | Get current weather for a location | `location` (string, required), `units` (string, optional) |
| `weather_get_forecast` | Get weather forecast for a location | `location` (string, required), `days` (integer, optional), `units` (string, optional) |
| `weather_search_location` | Search for location coordinates | `query` (string, required) |

### Swagger Petstore Tools (auto-generated) — via `/petstore/mcp`

These tools are **automatically generated** from the [Petstore API spec](https://petstore.swagger.io/v2/swagger.json) by AgentGateway's [OpenAPI-to-MCP](https://agentgateway.dev/docs/mcp/connect/openapi/) feature. No custom MCP server code is needed.

| Tool | Description | HTTP Method |
|------|-------------|-------------|
| `petstore_addPet` | Add a new pet to the store | POST /pet |
| `petstore_updatePet` | Update an existing pet | PUT /pet |
| `petstore_findPetsByStatus` | Find pets by status | GET /pet/findByStatus |
| `petstore_findPetsByTags` | Find pets by tags | GET /pet/findByTags |
| `petstore_getPetById` | Find pet by ID | GET /pet/{petId} |
| `petstore_updatePetWithForm` | Update pet with form data | POST /pet/{petId} |
| `petstore_deletePet` | Delete a pet | DELETE /pet/{petId} |
| `petstore_uploadFile` | Upload pet image | POST /pet/{petId}/uploadImage |
| `petstore_getInventory` | Returns pet inventories by status | GET /store/inventory |
| `petstore_placeOrder` | Place an order for a pet | POST /store/order |
| `petstore_getOrderById` | Find purchase order by ID | GET /store/order/{orderId} |
| `petstore_deleteOrder` | Delete purchase order by ID | DELETE /store/order/{orderId} |
| `petstore_createUser` | Create user | POST /user |
| `petstore_createUsersWithListInput` | Create list of users | POST /user/createWithList |
| `petstore_loginUser` | Log user into the system | GET /user/login |
| `petstore_logoutUser` | Log out current user | GET /user/logout |
| `petstore_getUserByName` | Get user by username | GET /user/{username} |
| `petstore_updateUser` | Update user | PUT /user/{username} |
| `petstore_deleteUser` | Delete user | DELETE /user/{username} |

### Mixed (all 11 tools) — via `/mixed/mcp`

The `/mixed` route exposes all tools from both JSONPlaceholder and Weather backends.

## Project Structure

```
mcp-gateway-demo/
+-- gateway/
|   +-- config.yaml              # AgentGateway configuration (routes, auth, backends)
+-- idp/                         # Local IdentityServer (OAuth/OIDC)
|   +-- IdentityServer/
|       +-- Program.cs           # Entry point
|       +-- Config.cs            # OAuth scopes and resources
|       +-- TestUsers.cs         # Test users (alice/bob)
|       +-- Dockerfile
+-- mcp-servers/
|   +-- jsonplaceholder/
|   |   +-- server.py            # JSONPlaceholder MCP server
|   |   +-- Dockerfile
|   +-- weather/
|       +-- server.py            # Weather MCP server
|       +-- Dockerfile
+-- nginx/
|   +-- nginx.conf               # Reverse proxy configuration
|   +-- snippets/                # CORS, headers, SSE support
+-- specs/
|   +-- SPECIFICATION.md         # Technical specification
+-- scripts/
|   +-- start-demo.sh            # Start script
+-- docker-compose.yml           # Service orchestration
+-- README.md                    # This file
```

## Docker Services

### AgentGateway
- **Image**: `ghcr.io/agentgateway/agentgateway:latest`
- **Port**: 3000 (MCP routes), 3001 (Admin UI)
- **Features**: Path-based MCP routing, OAuth integration, remote MCP proxying, admin UI
- **Docs**: https://agentgateway.dev/

### IdentityServer (IdP)
- **Build**: Local Dockerfile (`idp/IdentityServer`)
- **Port**: 5001
- **Features**: OAuth 2.1 / OpenID Connect provider
- **Test Users**: alice/alice, bob/bob
- **DCR**: Dynamic Client Registration at `/connect/dcr`

### JSONPlaceholder MCP
- **Build**: Local Dockerfile
- **Port**: 8001
- **Transport**: SSE (Server-Sent Events)
- **External API**: https://jsonplaceholder.typicode.com/

### Weather MCP
- **Build**: Local Dockerfile
- **Port**: 8002
- **Transport**: SSE (Server-Sent Events)
- **External API**: https://api.openweathermap.org/
- **API Key**: Optional (uses mock data without key)

## Security

### OAuth 2.1 Flow (Protected Routes)
- Uses **Authorization Code + PKCE** (secure for public clients)
- Dynamic Client Registration (DCR) supported
- Short-lived access tokens from local IdentityServer
- Gateway validates tokens via JWKS endpoint
- Only `/placeholder`, `/weather`, and `/mixed` routes require authentication

### Public Routes
- `/context7`, `/travel`, `/learn`, and `/petstore` routes have no authentication
- Traffic is proxied directly to remote MCP servers or translated from OpenAPI specs

### Demo Security Warnings
**Important**: This is a demo environment with the following limitations:
- Test users with simple passwords (alice/alice, bob/bob)
- Local IdentityServer uses development signing keys
- Not suitable for production use without hardening

## Documentation

### Project Documentation
- [Specification](specs/SPECIFICATION.md) - Detailed technical specification

### External References
- [AgentGateway](https://agentgateway.dev/) - Gateway documentation
- [Duende IdentityServer](https://docs.duendesoftware.com/) - OAuth/OIDC documentation
- [JSONPlaceholder](https://jsonplaceholder.typicode.com/guide/) - Fake REST API guide
- [OpenWeatherMap API](https://openweathermap.org/api) - Weather API documentation
- [Swagger Petstore](https://petstore.swagger.io/) - Petstore demo API
- [AgentGateway OpenAPI-to-MCP](https://agentgateway.dev/docs/mcp/connect/openapi/) - OpenAPI backend docs
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP specification

## Troubleshooting

### Common Issues

1. **Gateway not starting**: Check `docker compose logs mcp-gateway`
2. **OAuth errors**: Verify IdP is healthy at http://idp.localhost:8080/.well-known/openid-configuration
3. **Tools not visible**: Ensure MCP servers are running (`docker compose ps`)
4. **`*.localhost` not resolving**: Most browsers/OS resolve `*.localhost` to `127.0.0.1` by default. If not, add entries to your hosts file.

### Debug Commands

```bash
# Check all service status
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
```

## License

This demo is provided as-is for educational and demonstration purposes.

Individual components:
- AgentGateway: Apache 2.0
- Duende IdentityServer: Commercial (demo server used here)
- JSONPlaceholder: Free to use
- OpenWeatherMap: Free tier available

---

**Last Updated**: 2026-02-07
**Gateway**: AgentGateway
**Status**: Ready for use
