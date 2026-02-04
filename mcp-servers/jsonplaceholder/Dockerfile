# syntax=docker/dockerfile:1

# Stage 1: Build environment with uv
FROM python:3.14-slim AS builder

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:0.9.28 /uv /usr/local/bin/uv

WORKDIR /app

# Copy requirements first for layer caching
COPY requirements.txt .

# Create virtual environment and install dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
    uv venv /app/.venv && \
    uv pip install --python=/app/.venv/bin/python -r requirements.txt

# Stage 2: Runtime environment
FROM python:3.14-slim AS runtime

# Security: Run as non-root user
RUN groupadd --gid 1000 mcpuser && \
    useradd --uid 1000 --gid 1000 --shell /bin/bash --create-home mcpuser

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY --chown=mcpuser:mcpuser server.py .

# Set environment variables
ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV MCP_TRANSPORT=sse
ENV MCP_PORT=8001
ENV MCP_HOST=0.0.0.0

# Switch to non-root user
USER mcpuser

# Expose MCP server port
EXPOSE 8001

# Health check - verify server is responding (FastMCP doesn't have /health endpoint)
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD python -c "import socket; s=socket.socket(); s.settimeout(5); s.connect(('localhost',8001)); s.close()" || exit 1

# Run the MCP server
CMD ["python", "server.py"]
