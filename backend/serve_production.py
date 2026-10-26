"""Unified GozVision production server.

Serves, on one port, everything the platform needs in production:

- The Google ADK agent API (POST /run, POST /apps/{app}/users/{uid}/sessions,
  GET /docs, /list-apps, ...) exactly as ``python -m adk api_server`` does, so
  the Flutter copilot clients keep working unchanged.
- The GozVision MCP server (Model Context Protocol, streamable HTTP) mounted
  at ``/mcp`` — including the cv_enhance_accessibility_frame and
  smart_glasses_hud_process OpenCV tools.
- Live vision endpoints that prove the OpenCV 5 pipeline executes inside this
  container:
    GET  /vision/telemetry  — COOL pipeline telemetry (architecture, OpenCV
                              version, SIMD build paths, depth backend).
    POST /vision/enhance    — process a base64 JPEG through the OpenCV 5
                              pipeline (mode: enhanced_contrast,
                              glare_suppression, reading, spatial_depth).
- GET /health returns {"status":"ok"}.

Run:  uvicorn serve_production:app --host 0.0.0.0 --port 8080
"""
import base64
import contextlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np
from fastapi import HTTPException
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

from google.adk.cli.fast_api import get_fast_api_app
from mcp.server.transport_security import TransportSecuritySettings

from gozvision_mcp.server import mcp as mcp_server
from gozvision_vision.cool_pipeline import CoolGravitonPipeline

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
AGENT_NAME = "gozvision_agent"
PORT = int(os.environ.get("PORT", "8080"))
MAX_IMAGE_BYTES = 6 * 1024 * 1024

ADK_APP = get_fast_api_app(
    agents_dir=BACKEND_DIR,
    web=False,
    host="0.0.0.0",
    port=PORT,
)

MCP_APP = mcp_server.streamable_http_app(
    streamable_http_path="/mcp",
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=[
            "d7icpdzxenshi.cloudfront.net",
            "localhost:8080",
            "127.0.0.1:8080",
        ],
        allowed_origins=[
            "https://d7icpdzxenshi.cloudfront.net",
        ],
    ),
)
PIPELINE = CoolGravitonPipeline()

# Combine the ADK app's own lifespan with the MCP session-manager lifespan.
_adk_lifespan = ADK_APP.router.lifespan_context


@contextlib.asynccontextmanager
async def _combined_lifespan(app):
    async with contextlib.AsyncExitStack() as stack:
        await stack.enter_async_context(_adk_lifespan(app))
        await stack.enter_async_context(MCP_APP.router.lifespan_context(MCP_APP))
        yield


ADK_APP.router.lifespan_context = _combined_lifespan


@ADK_APP.get("/health")
def health() -> JSONResponse:
    return JSONResponse({"status": "ok"})


@ADK_APP.get("/vision/telemetry")
def vision_telemetry() -> JSONResponse:
    """Live proof of what actually runs in this container."""
    telemetry = PIPELINE.get_system_telemetry()
    estimator = PIPELINE.enhancer.spatial_estimator
    telemetry["depth_backend_used"] = (
        "opencv_dnn_onnx" if estimator.use_onnx else "geometric_fallback"
    )
    telemetry["depth_model"] = estimator.model_name if estimator.use_onnx else None
    telemetry["serving_app"] = "serve_production"
    return JSONResponse(telemetry)


class EnhanceRequest(BaseModel):
    image_base64: str
    mode: str = "enhanced_contrast"


@ADK_APP.post("/vision/enhance")
def vision_enhance(req: EnhanceRequest) -> JSONResponse:
    """Run a base64 JPEG through the OpenCV 5 pipeline and return the result."""
    if req.mode not in ("enhanced_contrast", "glare_suppression", "reading", "spatial_depth"):
        raise HTTPException(status_code=400, detail=f"unknown mode: {req.mode}")
    try:
        raw = base64.b64decode(req.image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="image_base64 is not valid base64")
    if len(raw) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="image too large")
    arr = np.frombuffer(raw, dtype=np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(status_code=400, detail="image_base64 did not decode to an image")
    processed, metadata = PIPELINE.process_frame(frame, mode=req.mode)
    ok, buf = cv2.imencode(".jpg", processed, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
    if not ok:
        raise HTTPException(status_code=500, detail="failed to encode processed frame")
    metadata["opencv_version"] = cv2.__version__
    return JSONResponse({
        "processed_base64": base64.b64encode(buf.tobytes()).decode("ascii"),
        "metadata": metadata,
    })


# Register the root fallback last so all ADK and GozVision API routes above
# take precedence while MCP keeps its own exact `/mcp` route.
ADK_APP.mount("/", MCP_APP, name="gozvision-mcp")

app = ADK_APP
