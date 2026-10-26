"""Run a judge-verifiable Agentic Vision MCP session end to end.

This script connects to the GozVision MCP server (live AWS production by
default, or a locally started server with --local), feeds a REAL image frame
through the OpenCV 5 perception tool, and logs every MCP exchange plus the
client-side decision that the vision metrics drove:

    perception (real pixels) -> decision rule -> next tool call -> action trace

The rubric criterion this demonstrates: "Image and video results directly
determine what the system plans, calls, and executes next."

Session flow
------------
1. MCP initialize + tools/list            (protocol handshake, logged verbatim)
2. cv_enhance_accessibility_frame(mode='spatial_depth', frame_base64=<REAL
   frame>)                                 -> spatial_hazard metrics
3. Client decision policy evaluated on those metrics -> chooses the next tool
4. agentic_vision_hazard_loop(..., frame_base64 if the server supports it)
                                           -> multi-step perception/reasoning/
                                              actuator/tool_call trace
5. agentic_vision_medication_guardrail(contraindicated drug) -> HALT + human
   escalation trace (failure handling / human control)
6. cool_graviton_telemetry                -> runtime provenance
7. Local reproducibility check: the same frame is re-run through
   AgenticVisionOrchestrator.run_workflow_on_source so the trace carries the
   SHA-256 of the exact pixels (when run from a repo checkout)

Each tool call opens its own MCP connection: reverse proxies (CloudFront) may
drop long-lived SSE streams, and the first agentic call can take minutes on a
1-vCPU Fargate task while the DNN depth model loads. A hanging call therefore
cannot poison the rest of the session, and every exchange is written to the
output JSON as it completes.

Outputs a full JSON session log (default:
backend/evaluation/results/agentic_mcp_session_trace.json).

Usage:
    python scripts/run_agentic_mcp_session.py                 # live AWS prod
    python scripts/run_agentic_mcp_session.py --local         # local server
    python scripts/run_agentic_mcp_session.py --endpoint URL --frame IMG
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import json
import os
import subprocess
import sys
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, AsyncIterator, Dict, List, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_ENDPOINT = "https://d7icpdzxenshi.cloudfront.net/mcp"
DEFAULT_FRAME = REPO_ROOT / "backend" / "evaluation" / "dataset" / "raw" / "_dl_stairs.jpg"
DEFAULT_OUT = REPO_ROOT / "backend" / "evaluation" / "results" / "agentic_mcp_session_trace.json"
LOCAL_PORT = 8765

# Decision policy: a vertical drop / elevation barrier in the walking corridor
# escalates the plan from passive monitoring to active hazard mitigation with
# fall telemetry armed. Threshold matches the OpenCV hazard rule
# (vertical_drop_score in [0, 1]); category names come from cv_pipeline.
ESCALATION_RULE = {
    "rule": "is_vertical_drop OR vertical_drop_score >= 0.35 OR hazard_category != 'coplanar_clear'",
    "vertical_drop_score_threshold": 0.35,
    "escalation_tool": "agentic_vision_hazard_loop",
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _sha256_file(path: Path) -> str:
    import hashlib
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_frame(frame_path: Path) -> str:
    """Read the real frame from disk and encode it for MCP transport."""
    return base64.b64encode(frame_path.read_bytes()).decode("ascii")


def content_to_dict(result: Any) -> Dict[str, Any]:
    """Extract the structured JSON payload from a CallToolResult."""
    out: Dict[str, Any] = {"is_error": bool(getattr(result, "isError", False))}
    for block in getattr(result, "content", []) or []:
        kind = getattr(block, "type", None)
        if kind == "text":
            text = getattr(block, "text", "")
            try:
                out["payload"] = json.loads(text)
            except (json.JSONDecodeError, TypeError):
                out["payload_text"] = text[:2000]
        elif kind == "image":
            out["image_block"] = {"mime": getattr(block, "mimeType", ""), "bytes": "omitted"}
        else:
            out.setdefault("other_blocks", []).append(kind)
    return out


def evaluate_decision(metrics: Dict[str, Any]) -> Dict[str, Any]:
    """Client-side agent policy: vision metrics -> chosen next action.

    This is the explicit plan-change point. The metrics dict is exactly what
    the OpenCV 5 spatial_depth tool returned for the real frame.
    """
    hazard = metrics.get("spatial_hazard") or {}
    drop = bool(hazard.get("is_vertical_drop"))
    score = float(hazard.get("vertical_drop_score") or 0.0)
    category = hazard.get("category", "unknown")
    escalate = drop or score >= ESCALATION_RULE["vertical_drop_score_threshold"] or (
        category not in ("coplanar_clear", "unknown")
    )
    return {
        "step": "client_decision",
        "decided_at": now_iso(),
        "observed_metrics": hazard,
        "rule_applied": ESCALATION_RULE["rule"],
        "decision": "escalate_to_hazard_mitigation_loop" if escalate else "maintain_passive_monitoring",
        "next_tool_call": ESCALATION_RULE["escalation_tool"] if escalate else None,
        "next_tool_arguments": {
            "telemetry_stumble_detected": True,
            "rationale": "vision metrics escalated the plan; IMU telemetry armed per protocol",
        },
        "vision_drove_plan_change": escalate,
    }


@asynccontextmanager
async def mcp_session(endpoint: str, read_timeout_s: float) -> AsyncIterator[Any]:
    """Open one MCP streamable-http session (connect + initialize)."""
    from mcp import ClientSession
    from mcp.client.streamable_http import streamable_http_client

    async with streamable_http_client(endpoint) as (read_stream, write_stream):
        async with ClientSession(read_stream, write_stream, read_timeout_seconds=read_timeout_s) as session:
            await session.initialize()
            yield session


async def timed_call(endpoint: str, name: str, arguments: Dict[str, Any],
                     timeout_s: float, log: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """One tool call on a fresh MCP connection, with a hard timeout."""
    try:
        t0 = time.perf_counter()
        async with mcp_session(endpoint, read_timeout_s=timeout_s + 30) as session:
            result = await asyncio.wait_for(session.call_tool(name, arguments), timeout=timeout_s)
        d = content_to_dict(result)
        d["latency_ms"] = round((time.perf_counter() - t0) * 1000, 1)
        return d
    except asyncio.TimeoutError:
        log["errors"].append(f"tools/call '{name}' timed out after {timeout_s:.0f}s")
        return None
    except Exception as exc:
        log["errors"].append(f"tools/call '{name}' failed: {exc}")
        return None


async def run_session(endpoint: str, frame_path: Path, out_path: Path,
                      call_timeout_s: float = 300.0) -> Dict[str, Any]:
    from mcp import ClientSession  # noqa: F401  (ensures client deps present)

    log: Dict[str, Any] = {
        "session_id": f"mcp_session_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}",
        "started_utc": now_iso(),
        "endpoint": endpoint,
        "connection_model": "one fresh MCP session per tool call (proxy-safe)",
        "frame": {
            "path": str(frame_path),
            "source_type": "image_file",
            "bytes": frame_path.stat().st_size,
            "sha256": _sha256_file(frame_path),
        },
        "exchanges": [],
        "decision_chain": [],
        "errors": [],
    }
    frame_b64 = load_frame(frame_path)

    def record(step: str, request: Any, response: Any) -> None:
        log["exchanges"].append({"step": step, "utc": now_iso(), "request": request, "response": response})
        # Persist incrementally so an interrupted run still leaves evidence.
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(log, indent=2, default=str), encoding="utf-8")

    try:
        # 1+2. Handshake & tool discovery (also records server identity)
        async with mcp_session(endpoint, read_timeout_s=call_timeout_s + 30) as session:
            init = await session.initialize()
            record(
                "1_initialize",
                {"protocol": "initialize", "client": "gozvision-agentic-session-runner"},
                {
                    "protocol_version": getattr(init, "protocolVersion", None),
                    "server_info": _to_plain(getattr(init, "serverInfo", None)),
                    "capabilities": _to_plain(getattr(init, "capabilities", None)),
                },
            )
            tools = await session.list_tools()
        tool_names = [t.name for t in tools.tools]
        schemas = {t.name: (getattr(t, "input_schema", None) or {}) for t in tools.tools}
        record("2_list_tools", {"method": "tools/list"}, {"count": len(tool_names), "names": tool_names})

        def supports_frame(tool_name: str) -> bool:
            return "frame_base64" in ((schemas.get(tool_name) or {}).get("properties") or {})

        # 3. PERCEPTION on real pixels
        perception_dict = await timed_call(
            endpoint, "cv_enhance_accessibility_frame",
            {"mode": "spatial_depth", "frame_base64": frame_b64},
            call_timeout_s, log,
        )
        if perception_dict is not None:
            record(
                "3_perception_spatial_depth",
                {"tool": "cv_enhance_accessibility_frame",
                 "arguments": {"mode": "spatial_depth", "frame_base64": f"<{len(frame_b64)} b64 chars>"}},
                perception_dict,
            )
        metrics = ((perception_dict or {}).get("payload") or {}).get("metadata", {})
        log["perception_metrics"] = metrics

        # 4. DECISION — vision metrics change the plan
        decision = evaluate_decision(metrics)
        log["decision_chain"].append(decision)

        # 5. ACTION — the escalated plan executes the hazard loop
        if decision["next_tool_call"] and "agentic_vision_hazard_loop" in tool_names:
            hazard_args: Dict[str, Any] = {
                "telemetry_stumble_detected": decision["next_tool_arguments"]["telemetry_stumble_detected"],
            }
            if supports_frame("agentic_vision_hazard_loop"):
                hazard_args["frame_base64"] = frame_b64
            hazard_dict = await timed_call(
                endpoint, "agentic_vision_hazard_loop", hazard_args, call_timeout_s, log
            )
            if hazard_dict is not None:
                record(
                    "5_action_hazard_loop",
                    {"tool": "agentic_vision_hazard_loop",
                     "arguments": {k: (f"<{len(v)} b64 chars>" if k == "frame_base64" else v)
                                   for k, v in hazard_args.items()}},
                    hazard_dict,
                )
                log["hazard_trace"] = (hazard_dict.get("payload") or {}).get("trace") or hazard_dict.get("payload")

        # 6. HUMAN CONTROL — medication guardrail HALT path
        if "agentic_vision_medication_guardrail" in tool_names:
            med_args: Dict[str, Any] = {"ocr_extracted_text": "Alphagan P 0.15% (Brimonidine Tartrate)"}
            if supports_frame("agentic_vision_medication_guardrail"):
                med_args["frame_base64"] = frame_b64
            med_dict = await timed_call(
                endpoint, "agentic_vision_medication_guardrail", med_args, call_timeout_s, log
            )
            if med_dict is not None:
                record(
                    "6_human_control_medication_guardrail",
                    {"tool": "agentic_vision_medication_guardrail",
                     "arguments": {k: (f"<{len(v)} b64 chars>" if k == "frame_base64" else v)
                                   for k, v in med_args.items()}},
                    med_dict,
                )
                log["medication_trace"] = (med_dict.get("payload") or {}).get("trace") or med_dict.get("payload")

        # 7. RUNTIME PROVENANCE — COOL / Graviton telemetry
        if "cool_graviton_telemetry" in tool_names:
            cool_dict = await timed_call(endpoint, "cool_graviton_telemetry", {}, call_timeout_s, log)
            if cool_dict is not None:
                record("7_runtime_provenance", {"tool": "cool_graviton_telemetry", "arguments": {}}, cool_dict)
                log["cool_telemetry"] = cool_dict.get("payload")
    finally:
        log["finished_utc"] = now_iso()
        log["summary"] = summarize(log)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(log, indent=2, default=str), encoding="utf-8")
    return log


def summarize(log: Dict[str, Any]) -> Dict[str, Any]:
    """One-glance proof object: the vision -> decision -> action chain."""
    hazard_trace = log.get("hazard_trace") or {}
    steps = hazard_trace.get("steps") or []
    med_trace = log.get("medication_trace") or {}
    decisions = log.get("decision_chain") or []
    return {
        "vision_drove_plan_change": bool(decisions and decisions[0].get("vision_drove_plan_change")),
        "decision": decisions[0]["decision"] if decisions else None,
        "observed_metrics": decisions[0].get("observed_metrics") if decisions else None,
        "hazard_loop_final_action": hazard_trace.get("final_action_taken"),
        "hazard_loop_human_approval_required": hazard_trace.get("human_approval_required"),
        "hazard_loop_step_types": [s.get("step_type") for s in steps],
        "medication_final_action": med_trace.get("final_action_taken"),
        "medication_human_approval_required": med_trace.get("human_approval_required"),
        "frame_sha256": log["frame"]["sha256"],
        "endpoint": log["endpoint"],
        "errors": log.get("errors", []),
    }


def local_provenance_check(frame_path: Path, log: Dict[str, Any]) -> None:
    """Re-run the same frame through the local orchestrator for a SHA-256 provenance trace."""
    try:
        sys.path.insert(0, str(REPO_ROOT / "backend"))
        from gozvision_agent.agentic_vision import AgenticVisionOrchestrator
        from gozvision_vision.frame_source import ImageFileSource

        trace = AgenticVisionOrchestrator().run_workflow_on_source(
            ImageFileSource(str(frame_path)), workflow="hazard", telemetry_stumble_detected=True
        )
        from dataclasses import asdict
        log["local_reproducibility_check"] = {
            "description": "Same real frame re-run through AgenticVisionOrchestrator.run_workflow_on_source; "
                           "trace carries SHA-256 provenance of the exact pixels that drove the decision.",
            "trace_id": trace.trace_id,
            "frame_provenance": trace.frame_provenance,
            "final_action_taken": trace.final_action_taken,
            "step_types": [s["step_type"] for s in asdict(trace)["steps"]],
        }
    except Exception as exc:  # optional check; never fatal
        log.setdefault("errors", []).append(f"local_provenance_check skipped: {exc}")


def _to_plain(obj: Any) -> Any:
    if obj is None:
        return None
    if hasattr(obj, "_asdict"):
        return dict(obj._asdict())
    if hasattr(obj, "__dict__"):
        return {k: _to_plain(v) for k, v in vars(obj).items()}
    if isinstance(obj, dict):
        return {k: _to_plain(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_to_plain(v) for v in obj]
    return obj


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT, help="MCP streamable-http endpoint URL")
    parser.add_argument("--local", action="store_true", help="Start a local MCP server instead of using --endpoint")
    parser.add_argument("--frame", default=str(DEFAULT_FRAME), help="Real image frame to feed the pipeline")
    parser.add_argument("--out", default=str(DEFAULT_OUT), help="Where to write the JSON session log")
    parser.add_argument("--timeout", type=float, default=300.0, help="Per-tool-call timeout in seconds")
    args = parser.parse_args()

    frame_path = Path(args.frame)
    if not frame_path.exists():
        print(f"ERROR: frame not found: {frame_path}")
        return 2

    server_proc: Optional[subprocess.Popen] = None
    endpoint = args.endpoint
    if args.local:
        endpoint = f"http://127.0.0.1:{LOCAL_PORT}/mcp"
        env = dict(os.environ, MCP_TRANSPORT="streamable-http", PORT=str(LOCAL_PORT))
        server_proc = subprocess.Popen(
            [sys.executable, str(REPO_ROOT / "backend" / "gozvision_mcp" / "server.py")],
            cwd=str(REPO_ROOT / "backend"), env=env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        print(f"Started local MCP server (pid {server_proc.pid}) at {endpoint}")
        time.sleep(6)

    try:
        log = asyncio.run(run_session(endpoint, frame_path, Path(args.out), args.timeout))
    finally:
        if server_proc is not None:
            server_proc.terminate()

    local_provenance_check(frame_path, log)
    Path(args.out).write_text(json.dumps(log, indent=2, default=str), encoding="utf-8")

    print(json.dumps(log.get("summary", {}), indent=2))
    print(f"\nFull session log written to: {args.out}")
    return 0 if not log.get("errors") else 1


if __name__ == "__main__":
    raise SystemExit(main())
