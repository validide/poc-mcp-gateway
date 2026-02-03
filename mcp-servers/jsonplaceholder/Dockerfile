# Build stage with uv for dependency resolution
FROM ghcr.io/astral-sh/uv:0.6.0 AS builder

WORKDIR /app

# Install dependencies using uv (ultra-fast Python package manager)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv venv /app/.venv && \
    uv pip install --no-cache \
    --python=/app/.venv/bin/python \
    mcp>=1.0.0 \
    fastmcp>=0.4.0

# Runtime stage
FROM python:3.12-slim-bookworm

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv

# Copy server code
COPY server.py .

# Set PATH to use venv
ENV PATH="/app/.venv/bin:$PATH"

# Security: Run as non-root user
RUN groupadd -r mcp && useradd -r -g mcp mcp
USER mcp

# Expose port for HTTP transport
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')" || exit 1

# Run server
CMD ["python", "server.py"]
