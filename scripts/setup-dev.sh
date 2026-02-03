#!/bin/bash
#===============================================================================
# MCP Gateway Demo - Development Environment Setup Script
# Configures modern Python 2026 development stack with uv, ruff, mypy
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PYTHON_VERSION="3.12"
UV_VERSION="0.6.0"

# Functions
print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     MCP Gateway Demo - Development Environment Setup           ║"
    echo "║         Python 3.12 + uv + Ruff + MyPy + VS Code               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}[STEP $1/7]${NC} $2"
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

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get OS type
get_os() {
    case "$OSTYPE" in
        linux-gnu*) echo "linux" ;;
        darwin*) echo "macos" ;;
        msys*|cygwin*|win32*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

OS=$(get_os)

# Step 1: Check Python version
step1_check_python() {
    print_step "1" "Checking Python installation..."
    
    # Try multiple Python commands (Windows compatibility)
    PYTHON_CMD=""
    for cmd in python3 python py; do
        if command_exists $cmd; then
            # Verify it's actually Python and get version
            version_output=$($cmd --version 2>&1)
            if echo "$version_output" | grep -q "^Python [0-9]\+\.[0-9]\+"; then
                PYTHON_CMD=$cmd
                break
            fi
        fi
    done
    
    if [ -z "$PYTHON_CMD" ]; then
        print_error "Python is not installed or not working properly."
        echo ""
        echo "Please install Python ${PYTHON_VERSION}+ first:"
        echo ""
        echo "Install options:"
        echo "  • macOS: brew install python@3.12"
        echo "  • Ubuntu/Debian: sudo apt install python3.12 python3.12-venv"
        echo "  • Windows: winget install Python.Python.3.12"
        echo "  • Or download from: https://python.org/downloads/"
        echo "  • Or use pyenv: pyenv install 3.12"
        echo ""
        exit 1
    fi
    
    # Extract version - handle both "Python 3.12.0" and error messages
    PYTHON_VERSION_FULL=$($PYTHON_CMD --version 2>&1 | grep -o "Python [0-9]\+\.[0-9]\+\.[0-9]\+" | head -1 | awk '{print $2}')
    
    if [ -z "$PYTHON_VERSION_FULL" ]; then
        print_error "Could not determine Python version. Is Python properly installed?"
        exit 1
    fi
    
    PYTHON_MAJOR=$(echo $PYTHON_VERSION_FULL | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION_FULL | cut -d. -f2)
    
    # Validate we got numeric versions
    if ! [[ "$PYTHON_MAJOR" =~ ^[0-9]+$ ]] || ! [[ "$PYTHON_MINOR" =~ ^[0-9]+$ ]]; then
        print_error "Could not parse Python version: $PYTHON_VERSION_FULL"
        exit 1
    fi
    
    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 12 ]); then
        print_error "Python ${PYTHON_VERSION}+ is required, but found ${PYTHON_VERSION_FULL}"
        echo ""
        echo "Please upgrade Python to ${PYTHON_VERSION}+ and try again."
        exit 1
    fi
    
    print_success "Found Python ${PYTHON_VERSION_FULL} (using: $PYTHON_CMD) ✓"
    
    # Check for python3-venv
    if [ "$OS" == "linux" ]; then
        if ! $PYTHON_CMD -m venv --help >/dev/null 2>&1; then
            print_warning "python3-venv module not found. Installing..."
            if command_exists apt; then
                sudo apt update && sudo apt install -y python3-venv python3-pip
            elif command_exists dnf; then
                sudo dnf install -y python3-virtualenv
            elif command_exists yum; then
                sudo yum install -y python3-virtualenv
            else
                print_error "Could not install python3-venv. Please install manually."
                exit 1
            fi
            print_success "python3-venv installed"
        fi
    fi
}

# Step 2: Install or update uv
step2_install_uv() {
    print_step "2" "Installing/updating uv (ultra-fast Python package manager)..."
    
    if command_exists uv; then
        UV_CURRENT=$(uv --version 2>&1 | awk '{print $2}')
        print_info "uv ${UV_CURRENT} is already installed"
        
        # Check if update needed
        if [ "$UV_CURRENT" != "$UV_VERSION" ]; then
            print_info "Updating uv to ${UV_VERSION}..."
            if [ "$OS" == "windows" ]; then
                powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
            else
                curl -LsSf https://astral.sh/uv/install.sh | sh
            fi
            print_success "uv updated to ${UV_VERSION}"
        else
            print_success "uv is up to date"
        fi
    else
        print_info "Installing uv ${UV_VERSION}..."
        
        if [ "$OS" == "windows" ]; then
            print_info "Detected Windows - using PowerShell installer"
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        else
            print_info "Detected Unix-like system - using curl installer"
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi
        
        # Add to PATH for this session
        if [ -f "$HOME/.cargo/bin/uv" ]; then
            export PATH="$HOME/.cargo/bin:$PATH"
        elif [ -f "$HOME/.local/bin/uv" ]; then
            export PATH="$HOME/.local/bin:$PATH"
        fi
        
        if command_exists uv; then
            print_success "uv installed successfully ✓"
        else
            print_warning "uv installed but not in PATH. Please restart your terminal or add to PATH:"
            echo "  export PATH=\"\$HOME/.cargo/bin:\$HOME/.local/bin:\$PATH\""
            echo ""
            echo "Then run this script again."
            exit 1
        fi
    fi
    
    echo ""
    print_info "uv version: $(uv --version)"
}

# Step 3: Create virtual environment
step3_create_venv() {
    print_step "3" "Creating Python virtual environment..."
    
    if [ -d ".venv" ]; then
        print_info "Virtual environment already exists at .venv/"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing virtual environment..."
            rm -rf .venv
        else
            print_success "Using existing virtual environment"
            return 0
        fi
    fi
    
    print_info "Creating virtual environment with uv..."
    uv venv --python $PYTHON_CMD
    
    if [ -f ".venv/bin/python" ] || [ -f ".venv/Scripts/python.exe" ]; then
        print_success "Virtual environment created at .venv/ ✓"
    else
        print_error "Failed to create virtual environment"
        exit 1
    fi
}

# Step 4: Install project dependencies
step4_install_deps() {
    print_step "4" "Installing project dependencies..."
    
    print_info "Installing main package with development dependencies..."
    uv pip install -e ".[dev]"
    
    print_success "Dependencies installed ✓"
    
    # Show installed packages
    echo ""
    print_info "Key packages installed:"
    echo "  • mcp - Model Context Protocol SDK"
    echo "  • fastmcp - Fast MCP server framework"
    echo "  • ruff - Ultra-fast Python linter & formatter"
    echo "  • mypy - Static type checker"
    echo "  • pytest - Testing framework"
    echo "  • pre-commit - Git hooks framework"
}

# Step 5: Setup pre-commit hooks
step5_precommit() {
    print_step "5" "Setting up pre-commit hooks..."
    
    if ! command_exists git; then
        print_warning "Git is not installed. Skipping pre-commit setup."
        return 0
    fi
    
    if [ ! -d ".git" ]; then
        print_info "Initializing git repository..."
        git init
        git add .
        git commit -m "Initial commit: MCP Gateway Demo setup" || true
        print_success "Git repository initialized"
    fi
    
    if [ -f ".pre-commit-config.yaml" ]; then
        print_info "Installing pre-commit hooks..."
        uv run pre-commit install
        uv run pre-commit autoupdate
        print_success "Pre-commit hooks installed ✓"
    else
        print_info "Creating pre-commit configuration..."
        cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
      - id: check-merge-conflict

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.0
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.8.0
    hooks:
      - id: mypy
        additional_dependencies: [types-requests]
EOF
        print_success "Created .pre-commit-config.yaml"
        
        print_info "Installing pre-commit hooks..."
        uv run pre-commit install
        print_success "Pre-commit hooks installed ✓"
    fi
}

# Step 6: Verify installation
step6_verify() {
    print_step "6" "Verifying installation..."
    
    local all_good=true
    
    # Check uv
    if command_exists uv; then
        print_success "uv: $(uv --version | awk '{print $2}')"
    else
        print_error "uv: Not found"
        all_good=false
    fi
    
    # Check Python in venv
    if [ -f ".venv/bin/python" ]; then
        VENV_PYTHON=$(.venv/bin/python --version 2>&1 | awk '{print $2}')
        print_success "Virtualenv Python: ${VENV_PYTHON}"
    elif [ -f ".venv/Scripts/python.exe" ]; then
        VENV_PYTHON=$(.venv/Scripts/python.exe --version 2>&1 | awk '{print $2}')
        print_success "Virtualenv Python: ${VENV_PYTHON}"
    else
        print_error "Virtual environment: Not properly configured"
        all_good=false
    fi
    
    # Check ruff
    if uv run ruff --version >/dev/null 2>&1; then
        print_success "Ruff: $(uv run ruff --version)"
    else
        print_error "Ruff: Not found"
        all_good=false
    fi
    
    # Check mypy
    if uv run mypy --version >/dev/null 2>&1; then
        print_success "MyPy: $(uv run mypy --version | head -1)"
    else
        print_error "MyPy: Not found"
        all_good=false
    fi
    
    # Check pytest
    if uv run pytest --version >/dev/null 2>&1; then
        print_success "pytest: $(uv run pytest --version | head -1)"
    else
        print_warning "pytest: Not found (optional)"
    fi
    
    # Run type check on MCP servers
    print_info "Running type checks on MCP servers..."
    if uv run mypy mcp-servers/ --ignore-missing-imports --follow-imports=silent 2>&1 | grep -q "error"; then
        print_warning "Type check: Some issues found (see output above)"
    else
        print_success "Type check: Passed ✓"
    fi
    
    # Run linting check
    print_info "Running linting check..."
    if uv run ruff check mcp-servers/ 2>&1 | grep -q "error\|error:"; then
        print_warning "Linting: Some issues found (run 'ruff check . --fix' to auto-fix)"
    else
        print_success "Linting: Passed ✓"
    fi
    
    echo ""
    if $all_good; then
        print_success "All core components verified ✓"
        return 0
    else
        print_error "Some components failed verification"
        return 1
    fi
}

# Step 7: Print next steps and helpful commands
step7_next_steps() {
    print_step "7" "Setup complete! Next steps:"
    
    cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║                    🎉 Setup Complete! 🎉                       ║
╚════════════════════════════════════════════════════════════════╝

📋 QUICK START COMMANDS:

# Activate virtual environment (optional - uv auto-detects)
source .venv/bin/activate  # Linux/macOS
.venv\Scripts\activate     # Windows

# Run code formatting
uv run ruff format .

# Run linting and auto-fix
uv run ruff check . --fix

# Run type checking
uv run mypy mcp-servers/

# Run tests (if you add tests/)
uv run pytest

# Start the demo
./scripts/start-demo.sh

🎯 DEVELOPMENT WORKFLOW:

1. VS Code Setup:
   - Open VS Code in this directory
   - Install recommended extensions (Ctrl+Shift+P → "Show Recommended Extensions")
   - Format on save is enabled via .vscode/settings.json

2. MCP Server Development:
   - Edit files in mcp-servers/
   - MyPy will show type errors in real-time
   - Ruff will lint and format on save

3. Testing Changes:
   - Format: uv run ruff format mcp-servers/
   - Lint: uv run ruff check mcp-servers/
   - Type check: uv run mypy mcp-servers/

4. Docker Development:
   - Build: docker compose build
   - Start: docker compose up -d
   - Logs: docker compose logs -f

📚 USEFUL DOCUMENTATION:

• uv documentation: https://docs.astral.sh/uv/
• Ruff documentation: https://docs.astral.sh/ruff/
• MyPy documentation: https://mypy.readthedocs.io/
• MCP specification: https://modelcontextprotocol.io/

🔧 TROUBLESHOOTING:

If you encounter issues:

1. Reinstall dependencies:
   uv pip install -e ".[dev]" --force-reinstall

2. Clear caches:
   rm -rf .ruff_cache .mypy_cache __pycache__ .pytest_cache

3. Recreate virtual environment:
   rm -rf .venv && uv venv && uv pip install -e ".[dev]"

4. Check tool versions:
   uv --version
   uv run ruff --version
   uv run mypy --version

💡 TIPS:

• Use 'uv run' instead of activating the virtual environment
  Example: uv run python script.py

• uv is 10-100x faster than pip for dependency resolution

• Ruff replaces: Black, isort, flake8, pycodestyle, pydocstyle

• MyPy strict mode is enabled - all functions must have type annotations

• Pre-commit hooks will run automatically on 'git commit'

═══════════════════════════════════════════════════════════════════

Happy coding! 🚀

EOF
}

# Main execution
main() {
    print_header
    
    step1_check_python
    step2_install_uv
    step3_create_venv
    step4_install_deps
    step5_precommit
    
    if step6_verify; then
        step7_next_steps
        exit 0
    else
        print_error "Setup completed with errors. Please review the output above."
        exit 1
    fi
}

# Handle script interruption
trap 'print_error "Setup interrupted"; exit 1' INT TERM

# Run main
main
