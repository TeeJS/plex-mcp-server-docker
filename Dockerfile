FROM python:3.12-slim

# Install build dependencies for cryptography package and clean apt cache
# in the same layer to minimize image size
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        libffi-dev \
        libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r mcp && useradd -r -g mcp -d /app -s /sbin/nologin mcp

WORKDIR /app

# Copy project files needed for installation
COPY pyproject.toml ./
COPY plex_mcp_server.py ./
COPY modules/ ./modules/

# Install the project and all dependencies from pyproject.toml,
# then remove build-only system packages to shrink the image
RUN pip install --no-cache-dir . && \
    apt-get purge -y gcc libffi-dev libssl-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Switch to non-root user
USER mcp

# Expose default SSE port
EXPOSE 3001

# Health check using TCP socket probe (avoids SSE streaming endpoint issues)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import socket; s=socket.create_connection(('localhost',3001),timeout=3); s.close()" || exit 1

# Run the MCP server in SSE mode
ENTRYPOINT ["python", "plex_mcp_server.py"]
CMD ["--transport", "sse", "--host", "0.0.0.0", "--port", "3001"]
