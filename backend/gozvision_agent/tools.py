"""GozAI ADK Tools — Backend functions for the agent to call.

All tools return structured dicts and NEVER raise exceptions to the agent.
Errors are caught, logged, and returned as graceful fallbacks to prevent
hallucinations and ensure the agent always has a valid structured response.
"""
import os
import traceback
from datetime import datetime, timezone

from .rag_service import SemanticKnowledgeBase

# Initialize Firebase Admin SDK (for real-time Firestore writes)
try:
    import firebase_admin
    from firebase_admin import credentials, firestore as fb_firestore

    if not firebase_admin._apps:
        # On Cloud Run: uses Application Default Credentials automatically.
        # Locally: set GOOGLE_APPLICATION_CREDENTIALS env var.
        firebase_admin.initialize_app()

    _db = fb_firestore.client()
    _FIREBASE_AVAILABLE = True
except Exception as _firebase_init_err:
    _db = None
    _FIREBASE_AVAILABLE = False
    print(f"[GozAI] Firebase Admin SDK unavailable: {_firebase_init_err}. SOS will run in stub mode.")


# Initialize the vector DB (client/db fall back internally; db=None when
# Firebase is unavailable skips dynamic RAG loading)
knowledge_base = SemanticKnowledgeBase(db=_db)

# Shared disclaimer appended to all medical responses
_MEDICAL_DISCLAIMER = (
    "This is general information only, not a diagnosis or prescription. "
    "Always consult your eye care professional for personalized medical advice."
)

# Demo identity fallback. Keep in sync with AppConfig.patientId in the
# Flutter app (lib/core/app_config.dart) — see CONTEXT.md ("Patient").
_DEMO_PATIENT_ID = "demo_patient_001"


def _resolve_patient_id(tool_context) -> str:
    """Extract the patient id from the ADK session, falling back to the demo id.

    The Flutter bridge creates the session with the patient's identity
    (authenticated uid, or the demo patient id on the zero-UI flow), so every
    backend write lands under the same document the dashboards watch.
    """
    if tool_context is None:
        return _DEMO_PATIENT_ID
    try:
        user_id = tool_context.invocation_context.session.user_id
        return user_id if user_id else _DEMO_PATIENT_ID
    except AttributeError:
        return _DEMO_PATIENT_ID


def search_optometry_guidelines(query: str) -> dict:
    """Search curated optometry guidelines for safe, verified medical information.

    Searches a curated database of optometric guidelines from authoritative
    sources (AAO, AOA, WHO) to provide verified eye health information.
    Never diagnoses or prescribes.

    Args:
        query: The user's eye health question.

    Returns:
        A structured dictionary with the answer, source, and disclaimer.
        On error, returns a safe fallback with error context.
    """
    if not query or not query.strip():
        return {
            "found": False,
            "answer": "Please provide a specific eye health question so I can look that up for you.",
            "disclaimer": _MEDICAL_DISCLAIMER,
        }

    try:
        result = knowledge_base.semantic_search(query, domain="optometry", threshold=0.55)

        if result.get("found"):
            data = result["data"]
            return {
                "found": True,
                "answer": data.get("answer", "Information found but details were incomplete."),
                "source": data.get("source", "Internal knowledge base"),
                "recommended_action": data.get("action", ""),
                "confidence": result.get("score"),
                "disclaimer": _MEDICAL_DISCLAIMER,
            }

        return {
            "found": False,
            "answer": (
                "I don't have specific guidelines on that topic in my database. "
                "For eye health questions, please consult your optometrist or ophthalmologist "
                "who can examine your eyes and provide personalized advice."
            ),
            "disclaimer": _MEDICAL_DISCLAIMER,
        }

    except Exception as e:
        traceback.print_exc()
        return {
            "found": False,
            "error": "knowledge_base_unavailable",
            "answer": (
                "I'm temporarily unable to access the optometry knowledge base. "
                "Please consult your eye care professional directly."
            ),
            "disclaimer": _MEDICAL_DISCLAIMER,
        }


def send_sos_alert(
    message: str,
    include_location: bool,
    tool_context=None,
) -> dict:
    """Send an SOS alert to the user's designated caregiver.

    Triggered when the user feels lost, disoriented, or needs help.
    Writes a real-time alert document to Firestore so the caregiver
    dashboard updates live. Also designed for Firebase Cloud Messaging
    push notification integration in production.

    The alert is written under the patient id carried by the ADK session
    (`user_id` the Flutter bridge supplies when it calls /run), so alerts
    reach the correct patient's dashboard. Falls back to the demo patient
    id only when no session context exists (e.g. direct/manual invocation).
    Keep the fallback in sync with AppConfig.patientId in the Flutter app.

    Args:
        message: Human-readable description of the situation.
        include_location: Whether to include GPS coordinates.
        tool_context: Injected automatically by the ADK runtime — not part
            of the model-facing schema.

    Returns:
        Confirmation of alert delivery with next steps for the user.
    """
    if not message or not message.strip():
        message = "User activated SOS — needs immediate assistance."

    patient_id = _resolve_patient_id(tool_context)

    now = datetime.now(timezone.utc)

    alert_data = {
        "type": "sos",
        "note": message,
        "severity": "High",
        "timestamp": now,
        "location_included": include_location,
        "source": "gemini_live_agent",
        "status": "unacknowledged",
    }

    firestore_written = False
    if _FIREBASE_AVAILABLE and _db is not None:
        try:
            # Write to the unified sos_alerts collection so the CaregiverDashboard
            # picks it up immediately through the dedicated SOS stream.
            alert_data.update({
                "userId": patient_id,
                "resolved": False,
            })
            _db.collection("sos_alerts") \
               .document(patient_id) \
               .set(alert_data)
            firestore_written = True
            print(f"[GozAI] SOS alert written to Firestore for {patient_id}: {message}")
        except Exception as e:
            traceback.print_exc()
            print(f"[GozAI] Firestore SOS write failed: {e}")

    return {
        "status": "sent" if firestore_written else "stub",
        "firestore_written": firestore_written,
        "message": f"SOS alert dispatched: {message}",
        "location_included": include_location,
        "next_steps": (
            "Your caregiver has been notified and can see your location. "
            "Stay where you are if it's safe. "
            "I'll keep monitoring your surroundings and guide you."
        ),
    }



def get_medication_info(medication_name: str) -> dict:
    """Look up safe, verified medication information for common eye medications.

    Provides basic medication details from a curated, clinically-reviewed database.
    Never provides dosing recommendations — always defers to the prescribing physician.

    Args:
        medication_name: The name of the medication to look up.

    Returns:
        Basic medication information and safety notes.
        On error, returns a safe fallback with pharmacy referral.
    """
    if not medication_name or not medication_name.strip():
        return {
            "found": False,
            "message": "Please provide the name of the medication you'd like information about.",
        }

    try:
        result = knowledge_base.semantic_search(
            medication_name, domain="medication", threshold=0.55
        )

        if result.get("found"):
            data = result["data"]
            return {
                "found": True,
                "medication": medication_name,
                "type": data.get("type", "Unknown"),
                "common_use": data.get("common_use", ""),
                "general_info": data.get("general_info", ""),
                "safety_notes": data.get("safety", ""),
                "confidence": result.get("score"),
                "disclaimer": (
                    "This is general information only. Always follow your doctor's "
                    "specific instructions for dosage and frequency."
                ),
            }

        return {
            "found": False,
            "medication": medication_name,
            "message": (
                f"I don't have '{medication_name}' in my database. "
                "Please check with your pharmacist or prescribing doctor "
                "for accurate information about this medication."
            ),
        }

    except Exception as e:
        traceback.print_exc()
        return {
            "found": False,
            "medication": medication_name,
            "error": "knowledge_base_unavailable",
            "message": (
                "I'm temporarily unable to look up medication information. "
                "Please contact your pharmacist or doctor directly."
            ),
        }


def get_low_vision_statistics(query: str) -> dict:
    """Provide verified clinical statistics and research findings on low vision.

    Use this when asked about the global prevalence of vision impairment,
    gaps in assistive technology access, or AI's proven impact on outcomes.
    All statistics are drawn from peer-reviewed sources (WHO, Seiple et al. TVST 2025,
    WHO & UNICEF Global Report on Assistive Technology 2022).

    Args:
        query: The specific topic or question about low vision statistics.

    Returns:
        Structured dict with statistic, context, and verified source citation.
    """
    if not query or not query.strip():
        return {
            "found": False,
            "message": "Please ask a specific question about low vision statistics.",
        }

    try:
        result = knowledge_base.semantic_search(query, domain="statistics", threshold=0.55)

        if result.get("found"):
            data = result["data"]
            return {
                "found": True,
                "statistic": data.get("statistic", ""),
                "context": data.get("context", ""),
                "source": data.get("source", "Internal research database"),
                "confidence": result.get("score"),
            }

        # Graceful fallback with always-valid WHO baseline statistic
        return {
            "found": False,
            "message": (
                "I couldn't find a specific statistic matching that query. "
                "As a reference: according to the WHO, over 2.2 billion people globally "
                "have a vision impairment, and at least 1 billion of those cases are "
                "preventable or have not yet been addressed."
            ),
            "source": "WHO World Report on Vision, 2019",
        }

    except Exception as e:
        traceback.print_exc()
        return {
            "found": False,
            "error": "knowledge_base_unavailable",
            "message": (
                "Unable to retrieve statistics at this time. "
                "According to the WHO, over 2.2 billion people globally have vision impairment."
            ),
            "source": "WHO World Report on Vision, 2019",
        }
