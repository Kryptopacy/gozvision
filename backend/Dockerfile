FROM python:3.13-slim

WORKDIR /app

# Install uv for fast dependency resolution
RUN pip install uv

# Copy project files
COPY pyproject.toml .
COPY gozvision_agent/ gozvision_agent/
COPY gozvision_mcp/ gozvision_mcp/
COPY gozvision_vision/ gozvision_vision/
COPY serve_production.py .

# Install dependencies with uv (ADK pulls uvicorn + FastAPI for serve_production)
RUN uv pip install --system .

# MiDaS-small ONNX depth model so the DNN depth backend is active in production.
# On download failure the pipeline falls back to the geometric backend and
# /vision/telemetry reports which backend is actually live.
RUN mkdir -p models && python -c "import urllib.request; urllib.request.urlretrieve('https://github.com/isl-org/MiDaS/releases/download/v2_1/model-small.onnx', 'models/model-small.onnx')" \
    || echo "WARN: depth model download failed; geometric_fallback backend will be used"

ENV PORT=8080
EXPOSE 8080

# Unified production server: ADK agent API + MCP streamable-HTTP (/mcp)
# + live OpenCV 5 vision endpoints (/vision/telemetry, /vision/enhance)
CMD ["python", "-m", "uvicorn", "serve_production:app", "--host", "0.0.0.0", "--port", "8080"]
