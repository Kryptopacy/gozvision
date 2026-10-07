"""GozVision Model Context Protocol (MCP) Server.

Exposes GozVision's agentic clinical capabilities to Alexa+ agents, LLM orchestrators,
and assistive devices via the Model Context Protocol (MCP standard).

Capabilities:
- clinical_knowledge_lookup: Grounded RAG retrieval for optometry & low-vision questions.
- trigger_emergency_sos: Dispatch SOS alert to clinics and caregivers.
- front_desk_recall_sweep: Run clinic outreach for unconfirmed visits and overdue recalls.
- draft_ambient_scribe_chart: Convert dialogue transcripts into clinical SOAP charts.
"""
from typing import Any, Optional
import os
import sys

try:
    from mcp.server.mcpserver import MCPServer
    mcp = MCPServer("GozVision Assistive & Clinical MCP Server")
except Exception:
    from mcp.server.fastmcp import FastMCP
    mcp = FastMCP("GozVision Assistive & Clinical MCP Server")

# Add parent directory to sys.path so we can import gozvision_agent modules cleanly
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from gozvision_agent.tools import (
    search_optometry_guidelines,
    send_sos_alert,
    get_medication_info,
    get_low_vision_statistics,
)
from gozvision_agent.recall import (
    compute_recall_worklist,
    render_message,
    run_sweep,
    AppointmentView,
    RecallItem,
)
from gozvision_agent.scribe import build_chart_prompt, parse_chart, draft_chart


@mcp.tool()
def clinical_knowledge_lookup(query: str) -> dict[str, Any]:
    """Retrieve verified clinical and low-vision guidance from the AAO, AOA, and WHO knowledge base.

    Args:
        query: The user or patient query (e.g., 'light sensitivity with glaucoma', 'magnifier selection', 'sudden flashes').
    """
    res = search_optometry_guidelines(query)
    return {
        "status": "success",
        "query": query,
        "results": res,
    }


@mcp.tool()
def trigger_emergency_sos(
    patient_id: str,
    message: str,
    severity: str = "high",
    clinic_id: Optional[str] = "demo_clinic_001",
    location: Optional[str] = None,
) -> dict[str, Any]:
    """Trigger an urgent SOS alert for a low-vision patient, notifying their designated caregiver and clinic.

    Args:
        patient_id: ID of the patient (e.g. 'pat_1' or auth UUID).
        message: Contextual description of the emergency or detected fall/struggle.
        severity: Urgency level ('high', 'medium', 'low').
        clinic_id: ID of the patient's affiliated eye care clinic.
        location: Optional coordinates or street address.
    """
    # Build tool_context with patient_id & clinic_id
    tool_context = {"user_id": patient_id, "clinic_id": clinic_id}
    res = send_sos_alert(message=message, include_location=bool(location), tool_context=tool_context)
    return {
        "status": "success",
        "patient_id": patient_id,
        "severity": severity,
        "details": res,
    }


@mcp.tool()
def front_desk_recall_sweep(clinic_id: str = "demo_clinic_001", horizon_days: int = 14) -> dict[str, Any]:
    """Run an automated front-desk outreach sweep to identify unconfirmed appointments, recent no-shows, and overdue annual exams.

    Args:
        clinic_id: The clinic identifier.
        horizon_days: Forward-looking day horizon for upcoming unconfirmed visits.
    """
    try:
        from gozvision_agent.db import service_client
        db = service_client()
        if db is None:
            return {
                "status": "simulated",
                "clinic_id": clinic_id,
                "message": "Supabase credentials not configured in backend/.env. Returning simulation baseline.",
                "queued_count": 0,
            }
        
        enqueued = run_sweep(clinic_id=clinic_id, horizon_days=horizon_days)
        return {
            "status": "success",
            "clinic_id": clinic_id,
            "generated_messages_count": len(enqueued),
            "enqueued": enqueued,
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
        }


@mcp.tool()
def draft_ambient_scribe_chart(encounter_id: str, transcript: str) -> dict[str, Any]:
    """Process an ambient exam dialogue transcript and generate a structured clinical SOAP chart draft.

    Args:
        encounter_id: Clinical encounter ID.
        transcript: Dialogue or clinical discussion between optometrist and patient.
    """
    try:
        import asyncio
        res = asyncio.run(draft_chart(encounter_id=encounter_id, transcript=transcript))
        return {
            "status": "success",
            "encounter_id": encounter_id,
            "chart": res,
        }
    except Exception as e:
        # Fallback to direct prompt & mock parsing
        parsed = parse_chart(
            "SUBJECTIVE: Patient reports visual changes.\n"
            "OBJECTIVE: Exam completed.\n"
            "ASSESSMENT: Evaluated.\n"
            "PLAN: Follow up as prescribed."
        )
        return {
            "status": "fallback",
            "encounter_id": encounter_id,
            "chart": parsed,
            "note": str(e),
        }


@mcp.tool()
def cv_enhance_accessibility_frame(
    mode: str = "enhanced_contrast",
    frame_base64: Optional[str] = None,
) -> dict[str, Any]:
    """Process an image frame through OpenCV 5 accessibility filters (CLAHE contrast, glare reduction, or text region detection).

    Args:
        mode: Enhancement filter mode: 'enhanced_contrast', 'glare_suppression', or 'reading'.
        frame_base64: Optional base64-encoded JPEG/PNG frame. If omitted, returns active pipeline configuration.
    """
    from gozvision_vision.cv_pipeline import LowVisionEnhancer
    import base64
    import cv2
    import numpy as np

    enhancer = LowVisionEnhancer()
    if not frame_base64:
        return {
            "status": "configured",
            "active_mode": mode,
            "available_modes": ["enhanced_contrast", "glare_suppression", "reading"],
            "opencv_version": cv2.__version__,
            "message": "OpenCV 5 accessibility pipeline active and ready for visual stream frames.",
        }

    try:
        img_bytes = base64.b64decode(frame_base64)
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"status": "error", "message": "Failed to decode frame"}

        processed, meta = enhancer.process_frame(img, mode=mode)
        _, buffer = cv2.imencode(".jpg", processed)
        encoded_out = base64.b64encode(buffer).decode("utf-8")
        return {
            "status": "success",
            "metadata": meta,
            "processed_frame_base64": encoded_out,
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


if __name__ == "__main__":
    # Standard stdio transport for MCP clients (Alexa+ host, Claude, or custom agent orchestrators)
    mcp.run()
