# MCP Gateway Demo

A complete demonstration of the Model Context Protocol (MCP) Gateway using IBM's Context Forge, featuring OAuth 2.1 authentication via Duende Demo Server and multiple MCP backends.

## 🎯 Overview

This demo showcases:
- **IBM MCP Context Forge** as the central gateway and registry
- **Duende IdentityServer Demo** for OAuth 2.1 authentication
- **Two custom MCP backends**:
  - HTTP-based MCP server fetching data from JSONPlaceholder API
  - Docker-based stdio MCP server for read-only filesystem operations
- **Virtual server composition** combining both backends behind OAuth 2.1 security

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Desktop MCP Clients                          │
│         (OpenCode Desktop / VS Code / ChatGPT Desktop)           │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ OAuth 2.1 + MCP Protocol
                       v
┌─────────────────────────────────────────────────────────────────┐
│                   MCP Gateway (localhost:4444)                  │
│              IBM Context Forge - Admin UI & API                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         v                           v
┌─────────────────┐     ┌──────────────────────┐
│ HTTP MCP Server │     │ stdio MCP Server     │
│ (Port 8001)     │     │ (via translator)     │
│                 │     │ (Port 8002)          │
│ • get_posts     │     │                      │
│ • get_users     │     │ • list_directory     │
│ • get_comments  │     │ • read_file          │
│ • get_todos     │     │ • get_file_info      │
│ • get_albums    │     │                      │
│ • get_photos    │     │ Docker Container     │
└─────────────────┘     └──────────────────────┘
         │                           │
         v                           v
┌─────────────────┐     ┌──────────────────────┐
│ JSONPlaceholder │     │ Host Filesystem      │
│ API             │     │ (Read-Only Mount)    │
└─────────────────┘     └──────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker Desktop or Docker Engine
- Docker Compose
- curl (for health checks)
- Ports 4444, 8001, and 8002 available
- Python 3.12+ (for development)

### Option A: Development Environment Setup

Configure modern Python development stack with uv, Ruff, and MyPy:

```bash
# Clone or navigate to the repository
cd mcp-gateway-demo

# Setup development environment (Python 3.12+, uv, ruff, mypy)
./scripts/setup-dev.sh

# This will install:
# • uv - Ultra-fast Python package manager
# • Ruff - Modern linter & formatter (replaces Black, isort, flake8)
# • MyPy - Strict type checker
# • Pre-commit hooks - Automatic code quality checks
# • VS Code extensions - Recommended Python tooling
```

### Option B: Docker-Only Demo (Linux/Mac/Git Bash)

```bash
# Clone or navigate to the repository
cd mcp-gateway-demo

# Make scripts executable (Linux/Mac)
chmod +x scripts/*.sh

# Start all services
./scripts/start-demo.sh
```

### Option C: Windows (WSL Recommended)

For Windows users, we recommend using **WSL 2** (Windows Subsystem for Linux) for the best compatibility with bash scripts and Docker:

#### Prerequisites
- [WSL 2 installed](https://learn.microsoft.com/en-us/windows/wsl/install) with a Linux distribution (Ubuntu recommended)
- [Docker Desktop with WSL 2 backend](https://docs.docker.com/desktop/wsl/)

#### Quick Start with WSL

```bash
# Open WSL terminal in the project directory
cd /mnt/c/code/mcp-gateway  # Adjust path to your Windows drive

# Setup development environment
./scripts/setup-dev.sh

# Or start the demo directly
./scripts/start-demo.sh

# Stop the demo
./scripts/stop-demo.sh
```

#### Alternative: Git Bash

If you prefer not to use WSL, you can run the scripts directly from Git Bash:

```bash
# Open Git Bash in the project folder
cd mcp-gateway-demo

# Make scripts executable and run
chmod +x scripts/*.sh
./scripts/start-demo.sh
```

**Note:** Git Bash provides a Unix-like environment but may have some limitations with certain features.

#### Alternative: PowerShell (Native Windows)

If you prefer using PowerShell natively without WSL or Git Bash, we provide a PowerShell setup script:

```powershell
# Open PowerShell in the project folder
cd mcp-gateway-demo

# Setup development environment (PowerShell edition)
.\scripts\setup-dev.ps1

# Start the demo (requires WSL or Docker Desktop)
docker compose up -d
```

**Note:** The PowerShell script provides the same development environment setup but runs natively on Windows without requiring WSL. However, for the actual demo (Docker containers), you'll still need Docker Desktop.

The script will:
1. Check prerequisites (Docker, ports)
2. Start the MCP Gateway on port 4444
3. Start the JSONPlaceholder MCP server on port 8001
4. Build and start the Filesystem MCP server (stdio)
5. Start the stdio-to-SSE translator on port 8002
6. Verify all services are healthy
7. Display instructions and start showing logs

### Access the Demo

Once started, you'll have access to:

| Service | URL | Credentials |
|---------|-----|---------------|
| Gateway Admin UI | http://localhost:4444/admin | admin@demo.local / demopass123 |
| Gateway API | http://localhost:4444 | Bearer token via API |
| JSONPlaceholder MCP | http://localhost:8001 | Direct access |
| Filesystem MCP | http://localhost:8002 | Via translator |

## 📋 Step-by-Step Demo Guide

### Phase 1: Infrastructure Setup (Automated)

The `start-demo.sh` script handles this phase automatically.

### Phase 2: Register Backend MCP Servers

#### Register JSONPlaceholder MCP

1. Open http://localhost:4444/admin
2. Login with: `admin@demo.local` / `demopass123`
3. Navigate to **"Gateways"** section
4. Click **"Register Gateway"**
5. Fill in:
   - **Name**: `jsonplaceholder-mcp`
   - **URL**: `http://host.docker.internal:8001/sse`
   - **Protocol**: `SSE`
   - **Description**: `JSONPlaceholder API as MCP tools`
6. Click **Save**
7. Wait for gateway to discover 8 tools automatically

#### Register Filesystem MCP

1. In the **"Gateways"** section, click **"Register Gateway"**
2. Fill in:
   - **Name**: `filesystem-mcp`
   - **URL**: `http://host.docker.internal:8002/sse`
   - **Protocol**: `SSE`
   - **Description**: `Read-only filesystem access via Docker`
3. Click **Save**
4. Wait for gateway to discover 3 tools automatically

### Phase 3: Create Virtual Server

1. Navigate to **"Servers"** section
2. Click **"Create Server"**
3. Fill in:
   - **Name**: `demo-combined-server`
   - **Description**: `Combined JSONPlaceholder and Filesystem tools with OAuth`
4. In **"Associated Tools"**, select all 11 tools:
   - 8 tools from `jsonplaceholder-mcp`
   - 3 tools from `filesystem-mcp`
5. Click **Save**
6. Note the **Server UUID** (needed for client configuration)

### Phase 4: Configure OAuth 2.1

1. Find your virtual server and click **"Edit"**
2. Navigate to **"Authentication"** tab
3. Configure OAuth:
   - **Provider**: `duende-demo`
   - **Discovery URL**: `https://demo.duendesoftware.com/.well-known/openid-configuration`
   - **Client ID**: `interactive.public`
   - **Redirect URI**: `http://localhost:4444/auth/callback`
   - **Scopes**: `openid profile email api`
4. Click **Save**

### Phase 5: Test OAuth Flow

1. Visit: `http://localhost:4444/servers/{UUID}/mcp`
   (replace `{UUID}` with your virtual server UUID)
2. You'll be redirected to Duende login page
3. Use any credentials (demo server accepts any login)
4. After authentication, you'll have access to all 11 tools

### Phase 6: Configure Desktop Client

#### OpenCode Desktop

1. Open OpenCode Desktop settings
2. Navigate to **MCP** section
3. Add new server:
   - **Name**: `demo-gateway`
   - **URL**: `http://localhost:4444/servers/{UUID}/mcp`
   - **OAuth**: Enabled
4. Save and restart OpenCode
5. On first use, complete OAuth flow in browser

**Documentation**: https://docs.opencode.ai/clients/mcp

#### VS Code (Cline/Roo Code)

1. Install Cline or Roo Code extension
2. Open extension settings
3. Add MCP server:
   - **Server URL**: `http://localhost:4444/servers/{UUID}/mcp`
   - **Transport**: HTTP
4. Configure OAuth in settings

**Documentation**: https://github.com/cline/cline#model-context-protocol-mcp

#### ChatGPT Desktop

1. Open ChatGPT Desktop
2. Navigate to **Settings** > **MCP**
3. Click **"Add Custom Server"**
4. Enter:
   - **Name**: `MCP Gateway Demo`
   - **URL**: `http://localhost:4444/servers/{UUID}/mcp`
5. Complete OAuth authentication when prompted

**Documentation**: https://help.openai.com/en/articles/10175700-mcp

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

### Filesystem Tools (3 tools)

| Tool | Description | Parameters |
|------|-------------|------------|
| `list_directory` | List directory contents | `path` (string, default: ".") |
| `read_file` | Read file contents | `path` (string, required) |
| `get_file_info` | Get file metadata | `path` (string, required) |

**Security Note**: Filesystem access is READ-ONLY and restricted to the mounted directory.

## 🛠️ Project Structure

```
mcp-gateway-demo/
├── .vscode/                     # VS Code configuration (2026-ready)
│   ├── settings.json           # Ruff, MyPy, Pylance settings
│   ├── extensions.json         # Recommended extensions
│   └── README.md               # VS Code setup guide
├── specs/
│   └── SPECIFICATION.md         # Detailed specification document
├── mcp-servers/
│   ├── jsonplaceholder/
│   │   ├── server.py           # HTTP MCP server (Python 3.12+)
│   │   ├── Dockerfile          # Multi-stage build with uv
│   │   └── requirements.txt    # Python dependencies
│   └── filesystem/
│       ├── server.py           # stdio MCP server (Python 3.12+)
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

### MCP Gateway
- **Image**: `ghcr.io/ibm/mcp-context-forge:1.0.0-BETA-2`
- **Port**: 4444
- **Features**: Admin UI, API, MCP protocol support
- **Data**: SQLite database in Docker volume

### JSONPlaceholder MCP
- **Build**: Local Dockerfile
- **Port**: 8001
- **Transport**: SSE (Server-Sent Events)
- **External API**: https://jsonplaceholder.typicode.com/

### Filesystem MCP
- **Build**: Local Dockerfile
- **Transport**: stdio (wrapped by gateway translator)
- **Port**: 8002 (translator endpoint)
- **Volume**: Read-only mount of host home directory

## 🔒 Security Considerations

### OAuth 2.1 Flow
- Uses **Authorization Code + PKCE** (secure for public clients)
- No client secret required (using `interactive.public` client)
- Short-lived access tokens from Duende demo server
- Gateway validates tokens against Duende

### Backend Security
- HTTP MCP server: No authentication (internal network only)
- Filesystem MCP: Read-only access, containerized, path restricted
- Both backends only accessible via gateway

### Demo Security Warnings
⚠️ **Important**: This is a demo environment with the following limitations:
- Hardcoded admin password (`demopass123`)
- Predictable JWT secret key
- Uses public Duende demo server
- Read-only filesystem access
- Not suitable for production use without hardening

## 🐛 Troubleshooting

### Port Conflicts

```bash
# Check what's using the ports
lsof -i :4444
lsof -i :8001
lsof -i :8002

# Or stop conflicting services
docker compose down
```

### Docker Issues

```bash
# Check Docker is running
docker info

# Check containers status
docker compose ps

# View logs
docker compose logs [service-name]

# Restart specific service
docker compose restart [service-name]
```

### OAuth Issues

1. Ensure redirect URI matches: `http://localhost:4444/auth/callback`
2. Check Duende demo server is accessible: https://demo.duendesoftware.com/
3. Verify virtual server UUID is correct in client configuration

### Network Issues

For cross-container communication on Linux:
- Use `host.docker.internal` (handled automatically in docker-compose)
- On some Linux setups, you may need to add to `/etc/hosts`:
  ```
  127.0.0.1 host.docker.internal
  ```

## 📚 Documentation

### Project Documentation
- [Specification](specs/SPECIFICATION.md) - Detailed technical specification

### External References
- [MCP Context Forge](https://ibm.github.io/mcp-context-forge/) - Gateway documentation
- [Duende IdentityServer](https://docs.duendesoftware.com/) - OAuth/OIDC documentation
- [JSONPlaceholder](https://jsonplaceholder.typicode.com/guide/) - Fake REST API guide
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

## 📝 Notes

- Demo uses Duende's public demo server (https://demo.duendesoftware.com/)
- Any login credentials work on the demo OAuth server
- Data is not persisted between restarts (SQLite in container)
- For production use, configure proper secrets and persistent storage

---

**Last Updated**: 2026-02-03  
**Demo Version**: 1.0  
**Status**: Ready for use
