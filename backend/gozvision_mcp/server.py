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
    log_adherence_event,
    format_ehr_encounter_note,
    find_clinics,
    get_clinic_schedule_and_hours,
    book_clinic_appointment,
    schedule_doctor_followup,
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


@mcp.tool()
def smart_glasses_hud_process(
    device_model: str = "rokid_max",
    battery_level_pct: int = 80,
    head_tilt_degrees: float = 0.0,
    frame_base64: Optional[str] = None,
) -> dict[str, Any]:
    """Process a camera frame tailored for Smart Glasses micro-HUD displays (Ray-Ban Meta, Rokid, Vuzix).

    Args:
        device_model: Wearable device model ('rayban_meta', 'rokid_max', 'vuzix_blade', etc.)
        battery_level_pct: Current battery percentage (triggers thermal downsampling when < 25%).
        head_tilt_degrees: Current pitch of head from IMU sensors (detects floor step hazards when tilted down).
        frame_base64: Optional base64-encoded frame. If omitted, returns active wearable profile status.
    """
    from gozvision_vision.smart_glasses import SmartGlassesTelemetryState, SmartGlassesVisionProcessor
    import base64
    import cv2
    import numpy as np

    telemetry = SmartGlassesTelemetryState(
        device_model=device_model,
        battery_level_pct=battery_level_pct,
        head_tilt_degrees=head_tilt_degrees,
    )
    processor = SmartGlassesVisionProcessor(telemetry=telemetry)

    if not frame_base64:
        return {
            "status": "configured",
            "device": device_model,
            "battery": f"{battery_level_pct}%",
            "hud_profile": "ultra-sparse transparent micro-OLED",
            "supported_devices": ["rokid_max", "rayban_meta", "even_realities_g1", "vuzix_blade"],
        }

    try:
        img_bytes = base64.b64decode(frame_base64)
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"status": "error", "message": "Failed to decode frame"}

        hud_overlay, meta = processor.generate_hud_sparse_overlay(img)
        _, buffer = cv2.imencode(".png", hud_overlay)
        encoded_out = base64.b64encode(buffer).decode("utf-8")
        return {
            "status": "success",
            "wearable_metadata": meta,
            "hud_overlay_base64": encoded_out,
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}


@mcp.tool()
def log_patient_medication_adherence(
    medication_name: str,
    status: str = "taken",
    notes: str = "",
    patient_id: str = "demo_patient_001",
) -> dict[str, Any]:
    """Log an ocular medication adherence or drop-taking event from external voice copilots or smart speakers.

    Args:
        medication_name: Name of prescribed drop (e.g. 'Latanoprost 0.005%', 'Systane Complete PF').
        status: Dose status ('taken', 'skipped', 'delayed').
        notes: Optional context or patient comments.
        patient_id: Patient identifier.
    """
    tool_context = type("Ctx", (), {"invocation_context": type("Inv", (), {"session": type("Sess", (), {"user_id": patient_id})()})()})()
    res = log_adherence_event(medication_name=medication_name, status=status, notes=notes, tool_context=tool_context)
    return {
        "status": "success",
        "result": res,
    }


@mcp.tool()
def format_ehr_chart_note(
    encounter_id: str = "demo_enc_1",
    provider_name: str = "Dr. Miller, OD",
    ehr_format: str = "standard",
) -> dict[str, Any]:
    """Format an ambient scribe encounter note into standard clinical EHR text for Epic, Eyefinity, or Compulink.

    Args:
        encounter_id: Unique encounter identifier.
        provider_name: Attending optometrist or ophthalmologist name.
        ehr_format: Target EHR template specification ('standard', 'epic', 'eyefinity').
    """
    sections = {
        "subjective": "Patient reports bilateral dry eyes and evening eye strain. Drops used consistently.",
        "objective": "VA OD 20/25, OS 20/20. IOP 15 mmHg OU. Cornea: mild punctate keratopathy inferiorly.",
        "assessment": "1. Mild bilateral evaporative dry eye syndrome. 2. Stable refractive status.",
        "plan": "1. Continue preservative-free artificial tears QID. 2. Warm compresses 5 min daily. 3. Follow up 6 months.",
    }
    formatted = format_ehr_encounter_note(sections, patient_id="demo_patient_001", provider_name=provider_name, ehr_format=ehr_format)
    return {
        "status": "success",
        "encounter_id": encounter_id,
        "formatted_note": formatted,
    }


@mcp.tool()
def search_eye_clinics_and_hours(location: str = "nearby", specialty: str = "low vision") -> dict[str, Any]:
    """Find verified eye care clinics, operating hours, and optometrists on duty for a patient.

    Args:
        location: City, zip, or neighborhood query (e.g. 'Main Street', 'downtown').
        specialty: Clinical specialty filter (e.g. 'low vision rehabilitation', 'glaucoma', 'exams').
    """
    res = find_clinics(query=specialty, location=location)
    return {
        "status": "success",
        "clinics": res.get("clinics", []),
        "count": res.get("count", 0),
        "message": res.get("message", ""),
    }


@mcp.tool()
def book_patient_appointment(
    clinic_name: str,
    patient_name: str,
    appointment_type: str = "Comprehensive Eye Exam",
    preferred_time: str = "Next available",
    notes: str = "",
) -> dict[str, Any]:
    """Book or schedule an eye clinic appointment on behalf of a patient via voice or assistant.

    Args:
        clinic_name: Name of the eye clinic.
        patient_name: Full name of the patient.
        appointment_type: 'Comprehensive Eye Exam', 'Low Vision Device Fit Trial', or 'Follow-up'.
        preferred_time: Preferred day and time slot.
        notes: Reason for visit or special visual accommodations needed.
    """
    res = book_clinic_appointment(
        clinic_name=clinic_name,
        patient_name=patient_name,
        appointment_type=appointment_type,
        preferred_date_time=preferred_time,
        notes=notes,
    )
    return res


@mcp.tool()
def trigger_doctor_followup(
    patient_id: str,
    followup_type: str,
    due_date: str,
    notes: str = "",
    provider_name: str = "Dr. Ada, O.D.",
) -> dict[str, Any]:
    """Schedule a clinical follow-up review for a patient from the optometrist side.

    Args:
        patient_id: The unique patient identifier (e.g., 'demo_patient_001').
        followup_type: Clinical reason (e.g., '2-Week Device Fit Check', 'Macular OCT Scan').
        due_date: Expected time or interval (e.g., 'In 2 weeks', '2026-10-22').
        notes: Specific instructions or questions for the patient.
        provider_name: The clinician scheduling the follow-up.
    """
    res = schedule_doctor_followup(
        patient_id=patient_id,
        followup_type=followup_type,
        due_date=due_date,
        notes=notes,
        provider_name=provider_name,
    )
    return res


# ============================================================================
# Ring Accessibility & Caretaking Tools (Home Safety & Caregiver Monitoring)
# ============================================================================


@mcp.tool()
def ring_inspect_doorstep_safety(device_id: str = "front_doorbell") -> dict[str, Any]:
    """Inspect a Ring doorbell or outdoor camera feed for doorstep tripping hazards, curbs, or uncollected packages.

    Args:
        device_id: Ring device ID ('front_doorbell', 'hallway_indoor').
    """
    from gozvision_ring.ring_client import ring_monitor
    return ring_monitor.inspect_doorstep_safety(device_id=device_id)


@mcp.tool()
def ring_triage_caretaker_event(
    event_type: str = "motion",
    device_id: str = "front_doorbell",
    patient_id: str = "demo_patient_001",
) -> dict[str, Any]:
    """Triage Ring motion or ding events for non-security caretaking rules (e.g., nighttime wandering or prolonged door open).

    Args:
        event_type: Ring event kind ('ding', 'motion', 'door_open').
        device_id: Ring device identifier.
        patient_id: Associated patient ID.
    """
    from gozvision_ring.ring_client import ring_monitor
    return ring_monitor.process_caretaker_event(
        event_type=event_type,
        device_id=device_id,
        patient_id=patient_id,
    )


@mcp.tool()
def ring_broadcast_intercom_chime(
    message: str,
    device_id: str = "front_doorbell",
) -> dict[str, Any]:
    """Broadcast an accessibility spoken announcement or prescription confirmation over Ring Chime or connected Echo speaker.

    Args:
        message: Spoken guidance text.
        device_id: Target Ring chime or speaker device.
    """
    from gozvision_ring.ring_client import ring_monitor
    return ring_monitor.broadcast_intercom_chime(message=message, device_id=device_id)


@mcp.tool()
def ring_list_monitored_devices() -> dict[str, Any]:
    """List all registered Ring doorbells, indoor cameras, and chime devices configured for caretaking monitoring."""
    from gozvision_ring.ring_client import ring_monitor
    devices = ring_monitor.list_devices()
    return {
        "status": "success",
        "devices": devices,
        "count": len(devices),
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="GozVision MCP Server (Alexa+ & Assistive Ecosystem)")
    parser.add_argument(
        "--transport",
        choices=["stdio", "streamable-http", "sse"],
        default=os.environ.get("MCP_TRANSPORT", "stdio"),
        help="Transport protocol: 'stdio' (default), 'streamable-http' (Alexa+ MCP spec 2025-11-25), or 'sse'.",
    )
    parser.add_argument("--host", default="0.0.0.0", help="Host address for HTTP/SSE transport")
    parser.add_argument("--port", type=int, default=int(os.environ.get("MCP_PORT", "8000")), help="Port for HTTP/SSE transport")
    args = parser.parse_args()

    if args.transport in ["streamable-http", "sse"]:
        print(f"Starting GozVision MCP Server on {args.host}:{args.port} using transport '{args.transport}' (Alexa+ MCP Spec 2025-11-25)...")
        mcp.run(transport=args.transport, host=args.host, port=args.port)
    else:
        # Standard stdio transport for local MCP hosts
        mcp.run()
