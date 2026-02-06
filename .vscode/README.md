# VS Code Development Setup

This project includes optimized VS Code configuration for Python MCP development in 2026.

## 🚀 Quick Setup

### 1. Install VS Code Extensions

Open VS Code and press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac), then run:

```
Extensions: Show Recommended Extensions
```

Or install individually:
- Python extension pack (auto-installs on project open)
- Ruff (formatting & linting)
- MyPy Type Checker
- Docker
- Even Better TOML

### 2. Install uv (Modern Python Package Manager)

```bash
# On macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# On Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### 3. Create Virtual Environment

```bash
# Using uv (recommended - 10-100x faster than pip)
uv venv

# Or using traditional Python
python3.12 -m venv .venv
```

### 4. Install Dependencies

```bash
# Using uv (instant)
uv pip install -e ".[dev]"

# Or using pip (slower)
pip install -e ".[dev]"
```

## 🛠️ Development Workflow

### Code Formatting

Ruff handles both linting and formatting (replaces Black, isort, flake8, etc.):

```bash
# Format all files
ruff format .

# Check and auto-fix linting issues
ruff check . --fix

# Check only
ruff check .
```

**VS Code Integration**: Format on save is enabled. Just save your file (`Ctrl+S`) and it auto-formats.

### Type Checking with MyPy

```bash
# Run mypy on all Python files
mypy mcp-servers/

# Check specific file
mypy mcp-servers/jsonplaceholder/server.py
```

**VS Code Integration**: MyPy runs automatically as you type. Errors appear in Problems panel.

### Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=mcp_servers --cov-report=html

# Run specific test file
pytest tests/test_jsonplaceholder.py

# Run with verbose output
pytest -v
```

### Running MCP Servers

```bash
# JSONPlaceholder HTTP MCP Server
uv run python mcp-servers/jsonplaceholder/server.py

# Filesystem stdio MCP Server (stdin/stdout)
echo '{"jsonrpc":"2.0","id":1,"method":"initialize"}' | uv run python mcp-servers/filesystem/server.py
```

## 📁 Project Structure

```
.vscode/
├── settings.json          # VS Code workspace settings
└── extensions.json        # Recommended extensions

mcp-servers/
├── jsonplaceholder/
│   ├── server.py         # HTTP MCP server
│   ├── server_test.py    # Tests (if created)
│   └── Dockerfile        # Multi-stage build with uv
└── filesystem/
    ├── server.py         # stdio MCP server
    └── Dockerfile        # Multi-stage build with uv

pyproject.toml            # Modern Python packaging (PEP 621)
```

## 🔧 VS Code Features Enabled

### Python Language Server (Pylance)
- **Type Checking Mode**: Basic (can be set to "strict" in settings)
- **Auto Import**: Enabled
- **Indexing**: Full workspace
- **Package Depth**: Configured for mcp/fastmcp

### Linting & Formatting
- **Ruff**: Primary linter and formatter
  - Line length: 88 characters
  - Double quotes
  - Import sorting
  - Auto-fix on save
- **MyPy**: Type checking
  - Strict mode enabled
  - Shows error codes and column numbers
  - Ignores missing imports for external packages

### Editor Enhancements
- **Rulers**: Line at 88 chars (PEP 8 compliant)
- **Format on Save**: Enabled
- **Code Actions on Save**: Auto-fix + organize imports
- **File Exclusions**: `__pycache__`, `.venv`, cache dirs
- **Watcher Exclusions**: Same as file exclusions for performance

### Docker Integration
- Compose command: `docker compose` (not deprecated `docker-compose`)
- No start page on extension load

### MCP Development
- Integrated with OpenCode extension
- Roo Cline support for AI-assisted development

## 🐛 Debugging

### Debug MCP Server

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug JSONPlaceholder MCP",
      "type": "debugpy",
      "request": "launch",
      "program": "${workspaceFolder}/mcp-servers/jsonplaceholder/server.py",
      "console": "integratedTerminal",
      "env": {
        "PYTHONPATH": "${workspaceFolder}"
      }
    },
    {
      "name": "Debug Filesystem MCP",
      "type": "debugpy",
      "request": "launch",
      "program": "${workspaceFolder}/mcp-servers/filesystem/server.py",
      "console": "integratedTerminal",
      "env": {
        "PYTHONPATH": "${workspaceFolder}",
        "MCP_BASE_PATH": "${env:HOME}"
      }
    }
  ]
}
```

Then press `F5` to start debugging.

## 📝 Code Quality Standards

### Ruff Rules Enabled
- **E, F**: pycodestyle errors & Pyflakes
- **I**: isort (import sorting)
- **N**: pep8-naming
- **UP**: pyupgrade (Python 3.12+ features)
- **B**: flake8-bugbear
- **C4**: flake8-comprehensions
- **SIM**: flake8-simplify
- **TCH**: flake8-type-checking
- **ASYNC**: flake8-async
- **S**: flake8-bandit (security)
- **RUF**: Ruff-specific rules

### MyPy Strict Mode
- All functions must have type annotations
- No implicit optional
- Strict equality checks
- Warn on unreachable code
- Disallow untyped calls/defs

## 🎯 Performance Tips

1. **Use uv for everything**: 10-100x faster than pip
   ```bash
   uv pip install -e ".[dev]"
   uv run python script.py
   uv run pytest
   ```

2. **VS Code Settings**: Already optimized in `.vscode/settings.json`
   - Disabled file watching on cache dirs
   - Excluded pycache from search
   - Configured Python analysis

3. **Docker Cache**: Multi-stage builds with BuildKit cache mount
   ```bash
   docker compose build --parallel
   ```

## 🔗 Useful Commands

```bash
# Check Python version
python --version  # Should be 3.12+

# Check uv version
uv --version

# Update dependencies
uv pip compile pyproject.toml -o requirements.txt  # if using pip-tools style
uv pip install -e ".[dev]" --upgrade

# Clean cache
rm -rf .ruff_cache .mypy_cache .pytest_cache __pycache__

# Docker shortcuts
docker compose up -d
docker compose logs -f
docker compose down

# Format & lint check (CI)
ruff format --check .
ruff check .
mypy mcp-servers/
```

## 📚 References

- [uv Documentation](https://docs.astral.sh/uv/)
- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [MyPy Documentation](https://mypy.readthedocs.io/)
- [VS Code Python](https://code.visualstudio.com/docs/python/python-tutorial)
- [MCP Protocol](https://modelcontextprotocol.io/)

---

**Last Updated**: 2026-02-03  
**Python Version**: 3.12+  
**Package Manager**: uv 0.6.0+
