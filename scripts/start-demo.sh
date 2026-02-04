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

echo -e "\n${BOLD}Services:${NC}"
echo -e "  ${CYAN}Gateway Admin UI:${NC}     http://localhost:4444/admin"
echo -e "  ${CYAN}Gateway API:${NC}          http://localhost:4444"
echo -e "  ${CYAN}JSONPlaceholder MCP:${NC}  http://localhost:8001"
echo -e "  ${CYAN}Weather MCP:${NC}          http://localhost:8002"

echo -e "\n${BOLD}Gateway Admin Credentials:${NC}"
echo -e "  ${CYAN}Email:${NC}    admin@demo.local"
echo -e "  ${CYAN}Password:${NC} asdQWE!@#"

echo -e "\n${BOLD}Next Steps:${NC}"
echo "  1. Open http://localhost:4444/admin"
echo "  2. Log in with Gateway admin credentials"
echo "  3. Navigate to 'Gateways' and register both MCP servers:"
echo "     - Name: jsonplaceholder-mcp"
echo "       URL: http://jsonplaceholder-mcp:8001/sse"
echo "     - Name: weather-mcp"
echo "       URL: http://weather-mcp:8002/sse"
echo "  4. Create a virtual server combining all tools"

echo -e "\n${BOLD}MCP Inspector:${NC}"
echo "  Run: npx @modelcontextprotocol/inspector"
echo "  URL: http://localhost:4444/servers/<UUID>/mcp"
echo "  Transport: Streamable HTTP"

echo -e "\n${BOLD}Useful Commands:${NC}"
echo "  View logs:    $COMPOSE_CMD logs -f"
echo "  Stop demo:    ./scripts/stop-demo.sh"
echo "  Check status: docker ps"

echo ""
