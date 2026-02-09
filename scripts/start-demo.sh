#!/usr/bin/env bash
# start-demo.sh - Start the MCP Gateway Demo (AgentGateway)

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
echo "========================================================"
echo "         MCP Gateway Demo (AgentGateway)                "
echo "========================================================"
echo -e "${NC}"

# Check Docker
echo -e "${CYAN}[1/3] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}x Docker not found. Please install Docker.${NC}"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo -e "${RED}x Docker daemon is not running.${NC}"
    exit 1
fi

echo -e "${GREEN}+ Docker is available${NC}"

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}x Docker Compose not found.${NC}"
    exit 1
fi

echo -e "${GREEN}+ Docker Compose is available${NC}"

# Generate nginx TLS certificate if it doesn't exist
NGINX_CERT_DIR="$PROJECT_DIR/nginx/certs"
if [ ! -f "$NGINX_CERT_DIR/cert.pem" ]; then
    echo -e "${YELLOW}Generating nginx dev TLS certificate...${NC}"
    mkdir -p "$NGINX_CERT_DIR"
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$NGINX_CERT_DIR/key.pem" -out "$NGINX_CERT_DIR/cert.pem" \
        -days 365 -nodes -subj "//CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:*.localhost" 2>/dev/null
    echo -e "${GREEN}+ TLS certificate generated${NC}"
else
    echo -e "${GREEN}+ TLS certificate exists${NC}"
fi

# Build images
echo -e "\n${CYAN}[2/3] Building images...${NC}"
$COMPOSE_CMD build --parallel
echo -e "${GREEN}+ Images built${NC}"

# Start all services
echo -e "\n${CYAN}[3/3] Starting services...${NC}"
$COMPOSE_CMD up -d
echo -e "${GREEN}+ Services started${NC}"

# Success message
echo -e "\n${BOLD}${GREEN}"
echo "========================================================"
echo "                    Demo Ready!                         "
echo "========================================================"
echo -e "${NC}"

echo -e "${YELLOW}Services are starting up. Use 'docker compose ps' to check status.${NC}"

echo -e "\n${BOLD}Main Services (via nginx):${NC}"
echo -e "  ${CYAN}Gateway MCP:${NC}      https://gateway.localhost:8080"
echo -e "  ${CYAN}Gateway Admin UI:${NC} https://gateway-ui.localhost:8080  ${YELLOW}(SSO login: alice / alice)${NC}"
echo -e "  ${CYAN}IdentityServer:${NC}   https://idp.localhost:8080"
echo -e "  ${CYAN}MCP Inspector:${NC}    https://inspector.localhost:8080"
echo -e "  ${CYAN}JSONPlaceholder:${NC}  https://jsonplaceholder.localhost:8080"
echo -e "  ${CYAN}Weather:${NC}          https://weather.localhost:8080"

echo -e "\n${BOLD}Direct Access:${NC}"
echo -e "  ${CYAN}Gateway MCP:${NC}      http://localhost:3000"
echo -e "  ${CYAN}Gateway Admin UI:${NC} http://localhost:3001"
echo -e "  ${CYAN}IdentityServer:${NC}   http://localhost:5001"
echo -e "  ${CYAN}MCP Inspector:${NC}    http://localhost:6274"
echo -e "  ${CYAN}JSONPlaceholder:${NC}  http://localhost:8001"
echo -e "  ${CYAN}Weather:${NC}          http://localhost:8002"

echo -e "\n${BOLD}Gateway Routes (via nginx):${NC}"
echo -e "  ${CYAN}Public (no auth):${NC}"
echo -e "    https://gateway.localhost:8080/context7/mcp           -> Context7"
echo -e "    https://gateway.localhost:8080/travel/mcp             -> Kismet Travel"
echo -e "    https://gateway.localhost:8080/learn/mcp              -> Microsoft Learn"
echo -e "    https://gateway.localhost:8080/petstore/mcp           -> Swagger Petstore (OpenAPI -> MCP)"
echo -e "    https://gateway.localhost:8080/placeholder-public/mcp -> JSONPlaceholder MCP"
echo -e "    https://gateway.localhost:8080/weather-public/mcp     -> Weather MCP"
echo -e "  ${CYAN}Protected (OAuth 2.1 + DCR):${NC}"
echo -e "    https://gateway.localhost:8080/placeholder/mcp   -> JSONPlaceholder MCP"
echo -e "    https://gateway.localhost:8080/weather/mcp       -> Weather MCP"
echo -e "    https://gateway.localhost:8080/mixed/mcp         -> JSONPlaceholder + Weather (combined)"

echo -e "\n${BOLD}IdentityServer Test Users:${NC}"
echo -e "  ${CYAN}User 1:${NC}   alice / alice"
echo -e "  ${CYAN}User 2:${NC}   bob / bob"

echo -e "\n${BOLD}Useful Commands:${NC}"
echo "  View logs:    $COMPOSE_CMD logs -f"
echo "  Stop demo:    ./scripts/stop-demo.sh"
echo "  Check status: docker compose ps"

echo ""

echo -e "\n${BOLD}MCP Inspector:${NC}"
# Extract the auth token from the inspector logs (retry a few times while it starts)
INSPECTOR_TOKEN=""
for i in 1 2 3 4 5; do
    INSPECTOR_TOKEN=$($COMPOSE_CMD logs mcp-inspector 2>/dev/null | grep -oP 'MCP_PROXY_AUTH_TOKEN=\K[a-f0-9]+' | tail -1)
    [ -n "$INSPECTOR_TOKEN" ] && break
    sleep 2
done
if [ -n "$INSPECTOR_TOKEN" ]; then
    echo -e "  ${CYAN}URL:${NC}   ${GREEN}http://localhost:6274/?MCP_PROXY_AUTH_TOKEN=${INSPECTOR_TOKEN}${NC}"
    echo -e "  ${CYAN}Token:${NC} ${GREEN}${INSPECTOR_TOKEN}${NC}"
else
    echo -e "  ${YELLOW}Token not yet available. Check logs: $COMPOSE_CMD logs mcp-inspector${NC}"
fi
echo -e "  ${YELLOW}Set server URL to: https://gateway.localhost:8080/context7/mcp${NC}"
echo ""
echo -e "${YELLOW}NOTE: Before connecting, accept the self-signed certificate by${NC}"
echo -e "${YELLOW}visiting https://gateway.localhost:8080 in your browser first.${NC}"
