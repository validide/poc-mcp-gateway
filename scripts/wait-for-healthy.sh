#!/usr/bin/env bash
# wait-for-healthy.sh - Wait for a Docker container to become healthy
#
# Usage: ./wait-for-healthy.sh <container_name> [timeout_seconds]
#
# Returns 0 if container becomes healthy, 1 on timeout or error

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

container=${1:-}
timeout=${2:-60}

if [[ -z "$container" ]]; then
    echo -e "${RED}Usage: $0 <container_name> [timeout_seconds]${NC}"
    echo "Example: $0 mcp-gateway 60"
    exit 1
fi

echo -e "${YELLOW}Waiting for $container to be healthy (timeout: ${timeout}s)...${NC}"

start_time=$(date +%s)
spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
spin_idx=0

while true; do
    # Get container health status
    status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_found")

    case "$status" in
        "healthy")
            echo -e "\n${GREEN}✓ $container is healthy!${NC}"
            exit 0
            ;;
        "unhealthy")
            echo -e "\n${RED}✗ $container is unhealthy${NC}"
            echo "Last 20 log lines:"
            docker logs "$container" --tail 20 2>&1 || true
            exit 1
            ;;
        "not_found")
            echo -e "\n${RED}✗ Container $container not found${NC}"
            exit 1
            ;;
        *)
            # Still starting - show spinner
            printf "\r  ${spinner[$spin_idx]} Status: $status"
            spin_idx=$(( (spin_idx + 1) % ${#spinner[@]} ))
            ;;
    esac

    # Check timeout
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [[ $elapsed -ge $timeout ]]; then
        echo -e "\n${RED}✗ Timeout waiting for $container (status: $status)${NC}"
        echo "Last 20 log lines:"
        docker logs "$container" --tail 20 2>&1 || true
        exit 1
    fi

    sleep 1
done
