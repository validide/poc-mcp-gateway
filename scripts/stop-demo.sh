#!/usr/bin/env bash
# stop-demo.sh - Stop the MCP Gateway Demo
#
# Usage: ./stop-demo.sh [--clean]
#
# Options:
#   --clean    Also remove volumes (persistent data)

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

# Check for --clean flag
CLEAN=false
if [[ "${1:-}" == "--clean" ]]; then
    CLEAN=true
fi

echo -e "${BOLD}${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           MCP Gateway Demo - Shutdown Script              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect compose command
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}✗ Docker Compose not found.${NC}"
    exit 1
fi

# Stop services
echo -e "${YELLOW}Stopping services...${NC}"

if [[ "$CLEAN" == "true" ]]; then
    echo -e "${YELLOW}Removing volumes (persistent data will be lost)...${NC}"
    $COMPOSE_CMD down -v --remove-orphans
else
    $COMPOSE_CMD down --remove-orphans
fi

echo -e "\n${GREEN}✓ Demo stopped successfully${NC}"

if [[ "$CLEAN" == "true" ]]; then
    echo -e "${YELLOW}Note: All persistent data has been removed.${NC}"
else
    echo -e "Data persisted in Docker volumes."
    echo -e "To remove volumes: ${CYAN}./scripts/stop-demo.sh --clean${NC}"
fi

echo ""
