#!/usr/bin/env bash
# start-demo.sh - Start the MCP Gateway Demo
#
# This script:
# 1. Checks prerequisites (Docker)
# 2. Verifies port availability
# 3. Builds MCP server images
# 4. Starts all services in correct order
# 5. Waits for health checks
# 6. Displays access information

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

# Change to project directory
cd "$PROJECT_DIR"

echo -e "${BOLD}${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           MCP Gateway Demo - Startup Script               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Check Docker
echo -e "${CYAN}[1/5] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker.${NC}"
    echo "  Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon is not running.${NC}"
    echo "  Please start Docker Desktop or the Docker service."
    exit 1
fi

echo -e "${GREEN}✓ Docker is available${NC}"

# Check docker compose
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}✗ Docker Compose not found.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Compose is available${NC}"

# Step 2: Check port availability
echo -e "\n${CYAN}[2/5] Checking port availability...${NC}"

check_port() {
    local port=$1
    local name=$2

    # Try different methods based on OS
    if command -v lsof &> /dev/null; then
        if lsof -Pi ":$port" -sTCP:LISTEN -t &> /dev/null; then
            echo -e "${RED}✗ Port $port ($name) is already in use${NC}"
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "${RED}✗ Port $port ($name) is already in use${NC}"
            return 1
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "${RED}✗ Port $port ($name) is already in use${NC}"
            return 1
        fi
    fi

    echo -e "${GREEN}✓ Port $port ($name) is available${NC}"
    return 0
}

ports_ok=true
check_port 5433 "PostgreSQL" || ports_ok=false
check_port 6379 "Redis" || ports_ok=false
check_port 4444 "MCP Gateway" || ports_ok=false
check_port 8001 "JSONPlaceholder MCP" || ports_ok=false
check_port 8002 "Weather MCP" || ports_ok=false

if [[ "$ports_ok" != "true" ]]; then
    echo -e "\n${RED}Please free up the required ports and try again.${NC}"
    exit 1
fi

# Step 3: Build images
echo -e "\n${CYAN}[3/6] Building MCP server images...${NC}"

$COMPOSE_CMD build --parallel

echo -e "${GREEN}✓ Images built successfully${NC}"

# Step 4: Start infrastructure services
echo -e "\n${CYAN}[4/6] Starting infrastructure services...${NC}"

echo "  Starting PostgreSQL..."
$COMPOSE_CMD up -d postgres

echo "  Starting Redis..."
$COMPOSE_CMD up -d redis

echo "  Waiting for PostgreSQL to be healthy..."
"$SCRIPT_DIR/wait-for-healthy.sh" mcp-postgres 60

echo "  Waiting for Redis to be healthy..."
"$SCRIPT_DIR/wait-for-healthy.sh" mcp-redis 30

# Step 5: Start MCP Gateway and Nginx
echo -e "\n${CYAN}[5/6] Starting MCP Gateway and Nginx...${NC}"

echo "  Starting MCP Gateway..."
$COMPOSE_CMD up -d mcp-gateway

echo "  Waiting for gateway to be healthy..."
"$SCRIPT_DIR/wait-for-healthy.sh" mcp-gateway 120

echo "  Starting Nginx (RFC 9728 proxy)..."
$COMPOSE_CMD up -d nginx

# Step 6: Start MCP servers
echo -e "\n${CYAN}[6/6] Starting MCP backend servers...${NC}"

echo "  Starting JSONPlaceholder MCP..."
$COMPOSE_CMD up -d jsonplaceholder-mcp

echo "  Starting Weather MCP..."
$COMPOSE_CMD up -d weather-mcp

echo "  Waiting for MCP servers to be healthy..."
"$SCRIPT_DIR/wait-for-healthy.sh" jsonplaceholder-mcp 60
"$SCRIPT_DIR/wait-for-healthy.sh" weather-mcp 60

# Success message
echo -e "\n${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    Demo Ready!                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Services:${NC}"
echo -e "  ${CYAN}Gateway Admin UI:${NC}     http://localhost:4444/admin"
echo -e "  ${CYAN}Gateway API:${NC}          http://localhost:4444"
echo -e "  ${CYAN}JSONPlaceholder MCP:${NC}  http://localhost:8001"
echo -e "  ${CYAN}Weather MCP:${NC}          http://localhost:8002"

echo -e "\n${BOLD}Admin Credentials:${NC}"
echo -e "  ${CYAN}Email:${NC}    admin@demo.local"
echo -e "  ${CYAN}Password:${NC} asdQWE!@#"

echo -e "\n${BOLD}Next Steps:${NC}"
echo "  1. Open http://localhost:4444/admin"
echo "  2. Log in with admin credentials"
echo "  3. Navigate to 'Gateways' and register both MCP servers:"
echo "     - Name: jsonplaceholder-mcp"
echo "       URL: http://jsonplaceholder-mcp:8001/sse"
echo "     - Name: weather-mcp"
echo "       URL: http://weather-mcp:8002/sse"
echo "  4. Create a virtual server combining all tools"
echo "  5. Configure OAuth 2.1 with Duende demo server"

echo -e "\n${BOLD}MCP Inspector:${NC}"
echo "  Run: npx @modelcontextprotocol/inspector"
echo "  URL: http://localhost:4444/servers/<UUID>/mcp"
echo "  Transport: Streamable HTTP"

echo -e "\n${BOLD}Useful Commands:${NC}"
echo "  View logs:    $COMPOSE_CMD logs -f"
echo "  Stop demo:    ./scripts/stop-demo.sh"
echo "  Check status: docker ps"

echo ""
