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
import threading
import time
from datetime import datetime, timedelta, timezone
from urllib.parse import quote

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np
from fastapi import Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

from google import genai
from google.adk.cli.fast_api import get_fast_api_app
from google.genai import types
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

WEB_ORIGINS = [
    "https://gozvision.vercel.app",
    "https://main.d1lr4zsb46he1m.amplifyapp.com",
]
ADK_APP.add_middleware(
    CORSMiddleware,
    allow_origins=WEB_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

_LIVE_MODEL = "gemini-3.8-live"
_LIVE_WS_BASE = (
    "wss://generativelanguage.googleapis.com/ws/"
    "google.ai.generativelanguage.v1beta.GenerativeService."
    "BidiGenerateContentConstrained"
)
_token_lock = threading.Lock()
_token_issued_at: dict[str, list[float]] = {}


def _rate_limit_token(user_id: str, limit: int = 6, window_seconds: int = 60) -> None:
    """Bound token minting per authenticated user without external state."""
    now = time.monotonic()
    with _token_lock:
        recent = [t for t in _token_issued_at.get(user_id, []) if now - t < window_seconds]
        if len(recent) >= limit:
            raise HTTPException(status_code=429, detail="Live token rate limit exceeded")
        recent.append(now)
        _token_issued_at[user_id] = recent


def _authenticated_user_id(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    jwt = authorization[7:].strip()
    if not jwt:
        raise HTTPException(status_code=401, detail="Missing bearer token")

    from gozvision_agent.db import service_client

    client = service_client()
    if client is None:
        raise HTTPException(status_code=503, detail="Identity service unavailable")
    try:
        response = client.auth.get_user(jwt)
        user = getattr(response, "user", None)
        user_id = getattr(user, "id", None)
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired session") from exc
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    return str(user_id)


@ADK_APP.post("/gemini/live-token")
def gemini_live_token(authorization: str | None = Header(default=None)) -> JSONResponse:
    """Mint a one-use Gemini Live token for an authenticated patient session."""
    user_id = _authenticated_user_id(authorization)
    _rate_limit_token(user_id)

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="Gemini Live is not configured")

    now = datetime.now(timezone.utc)
    try:
        client = genai.Client(
            api_key=api_key,
            http_options=types.HttpOptions(api_version="v1alpha"),
        )
        token = client.auth_tokens.create(
            config=types.CreateAuthTokenConfig(
                uses=1,
                expire_time=now + timedelta(minutes=5),
                new_session_expire_time=now + timedelta(minutes=1),
                live_connect_constraints=types.LiveConnectConstraints(
                    model=_LIVE_MODEL,
                    config=types.LiveConnectConfig(
                        response_modalities=["AUDIO"],
                        session_resumption=types.SessionResumptionConfig(),
                    ),
                ),
            )
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Unable to mint Gemini Live token") from exc
    if not token.name:
        raise HTTPException(status_code=502, detail="Gemini Live returned an empty token")

    return JSONResponse({
        "websocket_url": f"{_LIVE_WS_BASE}?access_token={quote(token.name, safe='')}",
        "model": f"models/{_LIVE_MODEL}",
        "uses": 1,
    })

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
    if os.environ.get("AWS_EXECUTION_ENV", "").startswith("AWS_ECS_FARGATE"):
        # Fargate allocates task CPU/memory; it is not a named EC2 instance.
        telemetry.pop("target_instance_type", None)
        telemetry.pop("instance_cost_per_hour_usd", None)
        telemetry["compute_runtime"] = "AWS ECS Fargate ARM64"
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
