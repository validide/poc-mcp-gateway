# MCP Gateway Demo

A complete demonstration of the Model Context Protocol (MCP) Gateway using IBM's Context Forge, featuring OAuth 2.1 authentication via a local Duende IdentityServer and multiple MCP backends.

## 🎯 Overview

This demo showcases:
- **IBM MCP Context Forge** as the central gateway and registry
- **Local Duende IdentityServer** for OAuth 2.1 authentication (with test users alice/bob)
- **Two public MCP backends**:
  - HTTP-based MCP server fetching data from JSONPlaceholder API
  - Weather MCP server providing real-time weather data via OpenWeatherMap API
- **Virtual server composition** combining both backends behind OAuth 2.1 security

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Desktop MCP Clients                          │
│              (OpenCode Desktop / MCP Inspector)                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ OAuth 2.1 + MCP Protocol
                       v
┌─────────────────────────────────────────────────────────────────┐
│                   MCP Gateway (localhost:8080)                  │
│              IBM Context Forge - Admin UI & API                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         v                           v
┌─────────────────┐     ┌──────────────────────┐
│ HTTP MCP Server │     │ Weather MCP Server   │
│ (Port 8001)     │     │ (Port 8002)          │
│                 │     │                      │
│ • get_posts     │     │ • get_forecast       │
│ • get_users     │     │ • get_current        │
│ • get_comments  │     │ • search_location    │
│ • get_todos     │     │                      │
│ • get_albums    │     │                      │
│ • get_photos    │     │                      │
└─────────────────┘     └──────────────────────┘
         │                           │
         v                           v
┌─────────────────┐     ┌──────────────────────┐
│ JSONPlaceholder │     │ OpenWeatherMap API   │
│ API             │     │                      │
└─────────────────┘     └──────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker Desktop or Docker Engine
- Docker Compose
- curl (for health checks)
- Ports 4444, 8001, and 8002 available
- Python 3.14+ (for development)

### Development Environment Setup

Configure modern Python development stack with uv, Ruff, and MyPy:

```bash
# Clone or navigate to the repository
cd mcp-gateway-demo

# Setup development environment (Python 3.14+, uv, ruff, mypy)
./scripts/setup-dev.sh

# This will install:
# • uv - Ultra-fast Python package manager
# • Ruff - Modern linter & formatter (replaces Black, isort, flake8)
# • MyPy - Strict type checker
# • Pre-commit hooks - Automatic code quality checks
# • VS Code extensions - Recommended Python tooling
```

### Access the Demo

Once started, you'll have access to:

| Service | URL | Credentials |
|---------|-----|---------------|
| Gateway Admin UI | http://localhost:8080/admin | admin@demo.local / asdQWE!@# |
| Gateway API | http://localhost:8080 | Bearer token via API |
| IdentityServer (IdP) | http://localhost:5001 | alice/alice or bob/bob |
| JSONPlaceholder MCP | http://localhost:8001 | Direct access |
| Weather MCP | http://localhost:8002 | Direct access |

## 📋 Step-by-Step Demo Guide

### Phase 1: Infrastructure Setup (Automated)

The `start-demo.sh` script handles this phase automatically.

### Phase 2: Register Backend MCP Servers

#### Register JSONPlaceholder MCP

1. Open http://localhost:8080/admin
2. Login with: `admin@demo.local` / `asdQWE!@#`
3. Navigate to **"Gateways"** section
4. Click **"Register Gateway"**
5. Fill in:
   - **Name**: `jsonplaceholder-mcp`
   - **URL**: `http://host.docker.internal:8001/sse`
   - **Protocol**: `SSE`
   - **Description**: `JSONPlaceholder API as MCP tools`
6. Click **Save**
7. Wait for gateway to discover 8 tools automatically

#### Register Weather MCP

1. In the **"Gateways"** section, click **"Register Gateway"**
2. Fill in:
   - **Name**: `weather-mcp`
   - **URL**: `http://host.docker.internal:8002/sse`
   - **Protocol**: `SSE`
   - **Description**: `Real-time weather data via OpenWeatherMap API`
3. Click **Save**
4. Wait for gateway to discover 3 tools automatically

### Phase 3: Create Virtual Server

1. Navigate to **"Servers"** section
2. Click **"Create Server"**
3. Fill in:
   - **Name**: `demo-combined-server`
   - **Description**: `Combined JSONPlaceholder and Weather tools with OAuth`
4. In **"Associated Tools"**, select all 11 tools:
   - 8 tools from `jsonplaceholder-mcp`
   - 3 tools from `weather-mcp`
5. Click **Save**
6. Note the **Server UUID** (needed for client configuration)

### Phase 4: Configure OAuth 2.1

1. Find your virtual server and click **"Edit"**
2. Navigate to **"Authentication"** tab
3. Configure OAuth:
   - **Provider**: `local-idp`
   - **Discovery URL**: `http://localhost:5001/.well-known/openid-configuration`
   - **Client ID**: (dynamically registered via DCR)
   - **Redirect URI**: `http://localhost:8080/auth/callback`
   - **Scopes**: `openid profile mcp:tools`
4. Click **Save**

**Note**: The local IdentityServer supports Dynamic Client Registration (DCR), so clients can be registered automatically.

### Phase 5: Test OAuth Flow

1. Visit: `http://localhost:8080/servers/{UUID}/mcp`
   (replace `{UUID}` with your virtual server UUID)
2. You'll be redirected to the local IdentityServer login page
3. Use test credentials: `alice` / `alice` (or `bob` / `bob`)
4. After authentication, you'll have access to all 11 tools

### Phase 6: Test with MCP Clients

#### MCP Inspector

1. Install and run MCP Inspector:
   ```bash
   npx -y @modelcontextprotocol/inspector
   ```
2. In the inspector interface:
   - **Server URL**: `http://localhost:8080/servers/{UUID}/mcp`
   - Complete OAuth flow when prompted
3. Test available tools:
   - Try `get_users` from JSONPlaceholder
   - Try `get_current` for weather data

#### OpenCode Desktop

1. Open OpenCode Desktop settings
2. Navigate to **MCP** section
3. Add new server:
   - **Name**: `demo-gateway`
   - **URL**: `http://localhost:8080/servers/{UUID}/mcp`
   - **OAuth**: Enabled
4. Save and restart OpenCode
5. On first use, complete OAuth flow in browser

**Documentation**: https://docs.opencode.ai/clients/mcp

## 🌐 Public Remote MCP Servers

In addition to the local MCP servers, you can register these public remote MCP servers in the gateway:

| Server | URL | Description |
|--------|-----|-------------|
| Context7 | https://mcp.context7.com/mcp | Context7 MCP Server |
| Kismet Travel | https://mcp.kismet.travel/mcp | Kismet Travel MCP Server |
| Microsoft Learn | https://learn.microsoft.com/api/mcp | Microsoft Learn Documentation MCP |

To register a public MCP server:
1. Open the Gateway Admin UI
2. Navigate to "Gateways" → "Register Gateway"
3. Enter the URL from the table above
4. Select protocol: "Streamable HTTP" or "SSE"

## 🔧 Available Tools

### JSONPlaceholder Tools (8 tools)

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_posts` | List all blog posts | None |
| `get_post` | Get specific post by ID | `id` (integer) |
| `get_comments` | Get comments for a post | `post_id` (integer) |
| `get_users` | List all users | None |
| `get_user` | Get specific user by ID | `id` (integer) |
| `get_todos` | List all todos | `user_id` (integer, optional) |
| `get_albums` | List all albums | `user_id` (integer, optional) |
| `get_photos` | Get photos from album | `album_id` (integer) |

### Weather Tools (3 tools)

| Tool | Description | Parameters |
|------|-------------|------------|
| `get_current` | Get current weather for a location | `location` (string, required), `units` (string, optional) |
| `get_forecast` | Get weather forecast for a location | `location` (string, required), `days` (integer, optional), `units` (string, optional) |
| `search_location` | Search for location coordinates | `query` (string, required) |

**API Note**: Uses OpenWeatherMap API for real-time weather data.

## 🛠️ Project Structure

```
mcp-gateway-demo/
├── .vscode/                     # VS Code configuration (2026-ready)
│   ├── settings.json           # Ruff, MyPy, Pylance settings
│   ├── extensions.json         # Recommended extensions
│   └── README.md               # VS Code setup guide
├── idp/                         # Local IdentityServer (OAuth/OIDC)
│   ├── IdentityServer.slnx     # .NET solution file
│   └── IdentityServer/
│       ├── Program.cs          # Entry point with Serilog
│       ├── HostingExtensions.cs # DI and middleware setup
│       ├── Config.cs           # OAuth scopes and resources
│       ├── TestUsers.cs        # Test users (alice/bob)
│       ├── Dockerfile          # Docker build
│       └── Pages/              # Login, Consent, etc. UI
├── specs/
│   └── SPECIFICATION.md         # Detailed specification document
├── mcp-servers/
│   ├── jsonplaceholder/
│   │   ├── server.py           # HTTP MCP server (Python 3.14+)
│   │   ├── Dockerfile          # Multi-stage build with uv
│   │   └── requirements.txt    # Python dependencies
│   └── weather/
│       ├── server.py           # HTTP MCP server (Python 3.14+)
│       ├── Dockerfile          # Multi-stage build with uv
│       └── requirements.txt    # Python dependencies
├── scripts/
│   ├── setup-dev.sh            # Development environment setup
│   ├── start-demo.sh           # Startup script with instructions
│   └── stop-demo.sh            # Cleanup script
├── docker-compose.yml          # Complete stack (2026 best practices)
├── pyproject.toml              # Modern Python packaging (uv, ruff, mypy)
└── README.md                   # This file
```

## 🐳 Docker Services

### IdentityServer (IdP)
- **Build**: Local Dockerfile (`idp/IdentityServer`)
- **Port**: 5001
- **Features**: OAuth 2.1 / OpenID Connect provider
- **Test Users**: alice/alice, bob/bob
- **DCR**: Dynamic Client Registration enabled at `/connect/dcr`

### PostgreSQL Database
- **Image**: `postgres:17`
- **Port**: 5433 (mapped from 5432)
- **Database**: `mcp`
- **Features**: Persistent storage for gateway data

### Redis Cache
- **Image**: `redis:7`
- **Port**: 6379
- **Features**: Session caching, registry caching

### MCP Gateway
- **Image**: `ghcr.io/ibm/mcp-context-forge:1.0.0-BETA-2`
- **Port**: 4444
- **Features**: Admin UI, API, MCP protocol support
- **Data**: PostgreSQL database, Redis cache

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
- **API Key**: Required (configured via environment variable)

## 🔒 Security Considerations

### OAuth 2.1 Flow
- Uses **Authorization Code + PKCE** (secure for public clients)
- Dynamic Client Registration (DCR) supported
- Short-lived access tokens from local IdentityServer
- Gateway validates tokens against local IdP (http://localhost:5001)

### Backend Security
- HTTP MCP server: No authentication (internal network only)
- Weather MCP: API key authentication for external API
- Both backends only accessible via gateway

### Demo Security Warnings
⚠️ **Important**: This is a demo environment with the following limitations:
- Hardcoded admin password (`asdQWE!@#`)
- Predictable JWT secret key
- Default PostgreSQL password (`postgres`)
- Local IdentityServer uses development signing keys (not for production)
- Test users with simple passwords (alice/alice, bob/bob)
- OpenWeatherMap API key in environment variable
- Not suitable for production use without hardening

## 📚 Documentation

### Project Documentation
- [Specification](specs/SPECIFICATION.md) - Detailed technical specification

### External References
- [MCP Context Forge](https://ibm.github.io/mcp-context-forge/) - Gateway documentation
- [Duende IdentityServer](https://docs.duendesoftware.com/) - OAuth/OIDC documentation
- [JSONPlaceholder](https://jsonplaceholder.typicode.com/guide/) - Fake REST API guide
- [OpenWeatherMap API](https://openweathermap.org/api) - Weather API documentation
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP specification
- [OpenCode MCP Client](https://docs.opencode.ai/) - Client documentation

### MCP Inspector

For testing MCP servers directly:

```bash
npx -y @modelcontextprotocol/inspector
```

## 🤝 Contributing

This is a demo project. For the actual MCP Gateway, see:
- [IBM/mcp-context-forge](https://github.com/IBM/mcp-context-forge)

## 📄 License

This demo is provided as-is for educational and demonstration purposes.

Individual components:
- IBM MCP Context Forge: Apache 2.0
- Duende IdentityServer: Commercial (demo server used here)
- JSONPlaceholder: Free to use
- OpenWeatherMap: Free tier available

## 📝 Notes

- Demo uses a local Duende IdentityServer instance (http://localhost:5001)
- Test users: `alice` / `alice` and `bob` / `bob`
- IdentityServer supports Dynamic Client Registration (DCR) at `/connect/dcr`
- Discovery document: http://localhost:5001/.well-known/openid-configuration
- Data is not persisted between restarts (in-memory storage)
- For production use, configure proper secrets and persistent storage

---

**Last Updated**: 2026-02-06
**Demo Version**: 1.0
**Status**: Ready for use
