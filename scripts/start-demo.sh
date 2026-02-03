#!/bin/bash
#===============================================================================
# MCP Gateway Demo Startup Script
# This script initializes the complete MCP Gateway demo environment
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GATEWAY_PORT=4444
HTTP_MCP_PORT=8001
FILESYSTEM_MCP_PORT=8002

# Functions
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          MCP Gateway Demo - Environment Setup                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}[STEP $1/6]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

check_prerequisites() {
    print_step "0" "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    print_success "Docker is available"
    
    # Check if ports are available
    local ports_available=true
    
    if lsof -i :$GATEWAY_PORT &> /dev/null || netstat -an | grep ":$GATEWAY_PORT " &> /dev/null; then
        print_error "Port $GATEWAY_PORT is already in use"
        ports_available=false
    fi
    
    if lsof -i :$HTTP_MCP_PORT &> /dev/null || netstat -an | grep ":$HTTP_MCP_PORT " &> /dev/null; then
        print_error "Port $HTTP_MCP_PORT is already in use"
        ports_available=false
    fi
    
    if ! $ports_available; then
        echo ""
        echo "Please free up these ports or change them in docker-compose.yml"
        exit 1
    fi
    
    print_success "All required ports are available"
}

start_gateway() {
    print_step "1" "Starting MCP Gateway..."
    
    docker compose up -d mcp-gateway
    
    # Wait for gateway to be healthy
    echo "  Waiting for gateway to be ready..."
    for i in {1..30}; do
        if docker compose ps mcp-gateway | grep -q "healthy"; then
            print_success "Gateway is healthy"
            return 0
        fi
        sleep 2
    done
    
    print_error "Gateway failed to become healthy within 60 seconds"
    docker compose logs mcp-gateway --tail=20
    exit 1
}

start_http_mcp() {
    print_step "2" "Starting JSONPlaceholder MCP Server..."
    
    docker compose up -d jsonplaceholder-mcp
    
    # Wait for HTTP MCP to be healthy
    echo "  Waiting for HTTP MCP server to be ready..."
    for i in {1..30}; do
        if docker compose ps jsonplaceholder-mcp | grep -q "healthy"; then
            print_success "JSONPlaceholder MCP server is healthy"
            return 0
        fi
        sleep 2
    done
    
    print_warning "HTTP MCP server health check timed out, continuing..."
}

build_filesystem_mcp() {
    print_step "3" "Building Filesystem MCP Server..."
    
    docker compose build filesystem-mcp
    print_success "Filesystem MCP server built"
}

start_filesystem_translate() {
    print_step "4" "Starting stdio-to-SSE translator for Filesystem MCP..."
    
    docker compose up -d filesystem-translate
    
    # Wait for translator to be ready
    echo "  Waiting for translator to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:$FILESYSTEM_MCP_PORT/health &> /dev/null; then
            print_success "Filesystem translator is ready"
            return 0
        fi
        sleep 2
    done
    
    print_warning "Filesystem translator health check timed out, continuing..."
}

verify_setup() {
    print_step "5" "Verifying setup..."
    
    local all_good=true
    
    # Check gateway
    if curl -s http://localhost:$GATEWAY_PORT/health | grep -q "ok\|healthy"; then
        print_success "Gateway is responding on port $GATEWAY_PORT"
    else
        print_error "Gateway is not responding"
        all_good=false
    fi
    
    # Check HTTP MCP
    if curl -s http://localhost:$HTTP_MCP_PORT/health &> /dev/null; then
        print_success "JSONPlaceholder MCP is responding on port $HTTP_MCP_PORT"
    else
        print_warning "JSONPlaceholder MCP health endpoint not responding (may be stdio-only)"
    fi
    
    # Check filesystem translator
    if curl -s http://localhost:$FILESYSTEM_MCP_PORT/health &> /dev/null; then
        print_success "Filesystem translator is responding on port $FILESYSTEM_MCP_PORT"
    else
        print_warning "Filesystem translator health endpoint not responding yet"
    fi
    
    if $all_good; then
        return 0
    else
        return 1
    fi
}

generate_instructions() {
    print_step "6" "Generating instructions..."
    
    cat << 'INSTRUCTIONS'

╔════════════════════════════════════════════════════════════════╗
║                   🎉 DEMO ENVIRONMENT READY!                   ║
╚════════════════════════════════════════════════════════════════╝

📋 QUICK START:

1️⃣  Access the Gateway Admin UI:
    URL: http://localhost:4444/admin
    
    Login Credentials:
    • Email: admin@demo.local
    • Password: demopass123

2️⃣  Register Backend MCP Servers:
    
    A. JSONPlaceholder MCP (HTTP):
       • Go to "Gateways" section
       • Click "Register Gateway"
       • Name: jsonplaceholder-mcp
       • URL: http://host.docker.internal:8001/sse
       • Protocol: SSE
       • Wait for 8 tools to be discovered
    
    B. Filesystem MCP (stdio via translator):
       • Go to "Gateways" section  
       • Click "Register Gateway"
       • Name: filesystem-mcp
       • URL: http://host.docker.internal:8002/sse
       • Protocol: SSE
       • Wait for 3 tools to be discovered

3️⃣  Create Virtual Server:
    • Go to "Servers" section
    • Click "Create Server"
    • Name: demo-combined-server
    • Description: Combined JSONPlaceholder and Filesystem tools
    • Select all 11 tools from both gateways
    • Save the server

4️⃣  Configure OAuth 2.1:
    • Edit the virtual server settings
    • Configure authentication:
      - Provider: duende-demo
      - Discovery URL: https://demo.duendesoftware.com/.well-known/openid-configuration
      - Client ID: interactive.public
      - Redirect URI: http://localhost:4444/auth/callback
      - Scopes: openid profile email api
    • Save settings

5️⃣  Test the Virtual Server:
    • Visit: http://localhost:4444/servers/{uuid}/mcp
    • Complete OAuth flow with Duende demo server
    • Tools will be accessible after authentication

6️⃣  Configure Your MCP Client:
    
    For OpenCode Desktop:
    • Documentation: https://docs.opencode.ai/clients/mcp
    • Server URL: http://localhost:4444/servers/{uuid}/mcp
    • OAuth will be handled automatically
    
    For VS Code (Cline/Roo Code):
    • Documentation: https://github.com/cline/cline#model-context-protocol-mcp
    • Add server in MCP settings
    
    For ChatGPT Desktop:
    • Documentation: https://help.openai.com/en/articles/10175700-mcp
    • Add custom server endpoint

📚 AVAILABLE TOOLS:

JSONPlaceholder (8 tools):
  • get_posts - List all posts
  • get_post - Get specific post
  • get_comments - Get comments for a post
  • get_users - List all users
  • get_user - Get specific user
  • get_todos - List todos
  • get_albums - List albums
  • get_photos - Get photos from album

Filesystem (3 tools):
  • list_directory - List directory contents
  • read_file - Read file contents
  • get_file_info - Get file metadata

🔧 USEFUL COMMANDS:

# View logs
docker compose logs -f [service-name]

# Stop all services
docker compose down

# Restart a service
docker compose restart [service-name]

# Check service status
docker compose ps

⚠️  IMPORTANT NOTES:

• This demo uses the public Duende demo server for OAuth 2.1
• The filesystem access is READ-ONLY and restricted to container
• All passwords and secrets are for demo purposes only
• Do not use in production without proper security hardening

🔗 REFERENCES:

• MCP Context Forge: https://ibm.github.io/mcp-context-forge/
• Duende Demo: https://demo.duendesoftware.com/
• JSONPlaceholder: https://jsonplaceholder.typicode.com/
• MCP Protocol: https://modelcontextprotocol.io/

Press Ctrl+C to stop all services and view logs...

INSTRUCTIONS
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down demo environment...${NC}"
    docker compose down
    print_success "Demo environment stopped"
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    print_header
    
    check_prerequisites
    start_gateway
    start_http_mcp
    build_filesystem_mcp
    start_filesystem_translate
    
    if verify_setup; then
        generate_instructions
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  All services are running. Showing logs (Ctrl+C to exit):${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        echo ""
        docker compose logs -f
    else
        print_error "Setup verification failed. Check logs above for details."
        docker compose logs --tail=50
        exit 1
    fi
}

# Run main
main
