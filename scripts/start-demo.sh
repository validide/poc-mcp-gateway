#!/usr/bin/env bash
# start-demo.sh - Start the MCP Gateway Demo

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo -e "${BOLD}${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           MCP Gateway Demo - Startup Script               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Docker
echo -e "${CYAN}[1/3] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker.${NC}"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon is not running.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is available${NC}"

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}✗ Docker Compose not found.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Compose is available${NC}"

# Build images
echo -e "\n${CYAN}[2/3] Building images...${NC}"
$COMPOSE_CMD build --parallel
echo -e "${GREEN}✓ Images built${NC}"

# Start all services
echo -e "\n${CYAN}[3/3] Starting services...${NC}"
$COMPOSE_CMD up -d
echo -e "${GREEN}✓ Services started${NC}"

# Success message
echo -e "\n${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    Demo Starting!                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Services are starting up. Use 'docker ps' to check status.${NC}"

echo -e "\n${BOLD}Services (via Nginx on port 8080):${NC}"
echo -e "  ${CYAN}Gateway Admin UI:${NC}     http://gateway.localhost:8080/admin"
echo -e "  ${CYAN}Gateway API:${NC}          http://gateway.localhost:8080"
echo -e "  ${CYAN}IdentityServer (IdP):${NC} http://idp.localhost:8080"
echo -e "  ${CYAN}MCP Inspector:${NC}        http://inspector.localhost:8080"
echo -e "  ${CYAN}JSONPlaceholder MCP:${NC}  http://jsonplaceholder.localhost:8080"
echo -e "  ${CYAN}Weather MCP:${NC}          http://weather.localhost:8080"

echo -e "\n${BOLD}Direct Service Ports (bypass Nginx):${NC}"
echo -e "  ${CYAN}IdentityServer:${NC}       http://localhost:5001"
echo -e "  ${CYAN}MCP Inspector:${NC}        http://localhost:6274"
echo -e "  ${CYAN}JSONPlaceholder MCP:${NC}  http://localhost:8001"
echo -e "  ${CYAN}Weather MCP:${NC}          http://localhost:8002"

echo -e "\n${BOLD}Gateway Admin Credentials:${NC}"
echo -e "  ${CYAN}Email:${NC}    admin@demo.local"
echo -e "  ${CYAN}Password:${NC} asdQWE!@#"

echo -e "\n${BOLD}IdentityServer Test Users:${NC}"
echo -e "  ${CYAN}User 1:${NC}   alice / alice"
echo -e "  ${CYAN}User 2:${NC}   bob / bob"

echo -e "\n${BOLD}IdentityServer Endpoints (via Nginx):${NC}"
echo -e "  ${CYAN}Discovery:${NC} http://idp.localhost:8080/.well-known/openid-configuration"
echo -e "  ${CYAN}DCR:${NC}       http://idp.localhost:8080/connect/dcr"

echo -e "\n${BOLD}Next Steps:${NC}"
echo "  1. Open http://gateway.localhost:8080/admin"
echo "  2. Log in with Gateway admin credentials"
echo "  3. Navigate to 'Gateways' and register MCP servers:"
echo "     - Name: jsonplaceholder-mcp"
echo "       URL: http://jsonplaceholder-mcp:8001/sse"
echo "     - Name: weather-mcp"
echo "       URL: http://weather-mcp:8002/sse"
echo "  4. Create a virtual server combining all tools"
echo "  5. Configure OAuth using local IdentityServer:"
echo "     - Discovery URL: http://idp.localhost:8080/.well-known/openid-configuration"
echo "     - Scopes: openid profile mcp:tools"
echo "  6. Test login with alice/alice or bob/bob"

echo -e "\n${BOLD}Public Remote MCP Servers (optional):${NC}"
echo -e "  ${CYAN}Context7:${NC}        https://mcp.context7.com/mcp"
echo -e "  ${CYAN}Kismet Travel:${NC}   https://mcp.kismet.travel/mcp"
echo -e "  ${CYAN}Microsoft Learn:${NC} https://learn.microsoft.com/api/mcp"

echo -e "\n${BOLD}MCP Inspector:${NC}"
echo -e "  ${CYAN}Open:${NC}      http://inspector.localhost:8080"
echo -e "  ${CYAN}Server URL:${NC} http://gateway.localhost:8080/servers/<UUID>/mcp"
echo -e "  ${CYAN}Transport:${NC}  Streamable HTTP"

echo -e "\n${BOLD}Useful Commands:${NC}"
echo "  View logs:    $COMPOSE_CMD logs -f"
echo "  Stop demo:    ./scripts/stop-demo.sh"
echo "  Check status: docker ps"

echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}All External URLs (accessible from host):${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo -e "\n${BOLD}Via Nginx (port 8080):${NC}"
echo -e "  http://localhost:8080                  → Gateway (default)"
echo -e "  http://gateway.localhost:8080          → Gateway"
echo -e "  http://gateway.localhost:8080/admin    → Gateway Admin UI"
echo -e "  http://idp.localhost:8080              → IdentityServer"
echo -e "  http://inspector.localhost:8080        → MCP Inspector"
echo -e "  http://jsonplaceholder.localhost:8080  → JSONPlaceholder MCP"
echo -e "  http://weather.localhost:8080          → Weather MCP"

echo -e "\n${BOLD}Direct Service Ports (bypass Nginx):${NC}"
echo -e "  http://localhost:5001                  → IdentityServer"
echo -e "  http://localhost:6274                  → MCP Inspector"
echo -e "  http://localhost:8001                  → JSONPlaceholder MCP"
echo -e "  http://localhost:8002                  → Weather MCP"

echo -e "\n${BOLD}Database & Cache:${NC}"
echo -e "  postgresql://localhost:5433/mcp        → PostgreSQL"
echo -e "  redis://localhost:6379                 → Redis"

echo ""
