#!/usr/bin/env bash
# setup-dev.sh - Set up development environment for MCP Gateway Demo
#
# This script:
# 1. Checks Python version (3.14+ required)
# 2. Installs uv package manager
# 3. Creates virtual environment
# 4. Installs dependencies
# 5. Sets up pre-commit hooks
# 6. Verifies installation

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
echo "║      MCP Gateway Demo - Development Environment Setup     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Check Python version
echo -e "${CYAN}[1/5] Checking Python version...${NC}"

# Find Python 3.14+
PYTHON_CMD=""
for cmd in python3.14 python3 python; do
    if command -v "$cmd" &> /dev/null; then
        version=$("$cmd" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)

        if [[ "$major" -ge 3 ]] && [[ "$minor" -ge 14 ]]; then
            PYTHON_CMD="$cmd"
            break
        fi
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    echo -e "${RED}✗ Python 3.14+ required but not found${NC}"
    echo ""
    echo -e "${YELLOW}This project requires Python 3.14 or later.${NC}"
    echo ""
    echo "Current Python version detected:"
    python --version 2>&1 || python3 --version 2>&1 || echo "  No Python found"
    echo ""
    echo "To install Python 3.14:"
    echo "  • Windows: https://www.python.org/downloads/"
    echo "  • macOS:   brew install python@3.14"
    echo "  • Linux:   Use pyenv or your package manager"
    echo ""
    echo "Alternatively, use uv to install Python 3.14:"
    echo "  uv python install 3.14"
    echo ""
    exit 1
fi

python_version=$("$PYTHON_CMD" --version 2>&1)
echo -e "${GREEN}✓ Found: $python_version${NC}"

# Step 2: Install uv
echo -e "\n${CYAN}[2/5] Setting up uv package manager...${NC}"

if command -v uv &> /dev/null; then
    uv_version=$(uv --version 2>&1)
    echo -e "${GREEN}✓ uv already installed: $uv_version${NC}"
else
    echo "Installing uv..."
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    else
        # macOS/Linux
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    if command -v uv &> /dev/null; then
        echo -e "${GREEN}✓ uv installed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to install uv${NC}"
        echo "  Please install manually: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    fi
fi

# Step 3: Create virtual environment
echo -e "\n${CYAN}[3/5] Creating virtual environment...${NC}"

if [[ -d ".venv" ]]; then
    echo -e "${YELLOW}Existing .venv found, recreating...${NC}"
    rm -rf .venv
fi

uv venv --python "$PYTHON_CMD"
echo -e "${GREEN}✓ Virtual environment created${NC}"

# Step 4: Install dependencies
echo -e "\n${CYAN}[4/5] Installing dependencies...${NC}"

# Activate venv for subsequent commands
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    source .venv/Scripts/activate
else
    source .venv/bin/activate
fi

uv pip install -e ".[dev]"
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Step 5: Set up pre-commit
echo -e "\n${CYAN}[5/5] Setting up pre-commit hooks...${NC}"

# Create pre-commit config if it doesn't exist
if [[ ! -f ".pre-commit-config.yaml" ]]; then
    cat > .pre-commit-config.yaml << 'EOF'
# Pre-commit configuration for MCP Gateway Demo
# See https://pre-commit.com for more information

repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.19.0
    hooks:
      - id: mypy
        additional_dependencies:
          - pydantic>=2.12.0
          - httpx>=0.28.0
        args: [--ignore-missing-imports]

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
EOF
    echo -e "${GREEN}✓ Created .pre-commit-config.yaml${NC}"
fi

pre-commit install
echo -e "${GREEN}✓ Pre-commit hooks installed${NC}"

# Verify installation
echo -e "\n${BOLD}Verifying installation...${NC}"
echo -e "  Python:  $(python --version)"
echo -e "  uv:      $(uv --version)"
echo -e "  Ruff:    $(ruff --version)"
echo -e "  MyPy:    $(mypy --version)"
echo -e "  Pytest:  $(pytest --version | head -1)"

# Success message
echo -e "\n${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Development Setup Complete!                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo "  1. Activate the environment:"
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ACTIVATE_CMD="source .venv/Scripts/activate"
else
    ACTIVATE_CMD="source .venv/bin/activate"
fi
echo -e "     ${CYAN}${ACTIVATE_CMD}${NC}"
echo ""
echo "  2. Run the demo:"
echo -e "     ${CYAN}./scripts/start-demo.sh${NC}"
echo ""
echo "  3. Run tests:"
echo -e "     ${CYAN}pytest${NC}"
echo ""
echo "  4. Format code:"
echo -e "     ${CYAN}ruff format .${NC}"
echo ""
echo "  5. Run linter:"
echo -e "     ${CYAN}ruff check . --fix${NC}"
echo ""

# Tip about sourcing
echo -e "${YELLOW}Tip:${NC} To auto-activate after setup, run this script with 'source':"
echo -e "     ${CYAN}source ./scripts/setup-dev.sh${NC}"
echo ""

# If script was sourced (not executed), activate the venv automatically
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo -e "${GREEN}Activating virtual environment...${NC}"
    $ACTIVATE_CMD
    echo -e "${GREEN}✓ Virtual environment is now active${NC}"
fi
