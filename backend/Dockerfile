FROM python:3.13-slim

WORKDIR /app

# Install uv for fast dependency resolution
RUN pip install uv

# Copy project files
COPY pyproject.toml .
COPY gozvision_agent/ gozvision_agent/
COPY gozvision_mcp/ gozvision_mcp/
COPY gozvision_vision/ gozvision_vision/

# Install dependencies with uv
RUN uv pip install --system .

# Expose port for Cloud Run
ENV PORT=8080
EXPOSE 8080

# Run GozVision Alexa+ Streamable HTTP MCP Server & Health Ingress
CMD ["python", "-m", "gozvision_mcp.server", "--transport", "streamable-http", "--host", "0.0.0.0", "--port", "8080"]
