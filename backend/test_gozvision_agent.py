"""Offline tests for the GozVision agent package.

Run from backend/: python test_gozvision_agent.py
Needs GEMINI_API_KEY only for live embedding; without it the knowledge base
initializes in the graceful no-client path and the identity/stub tests still
run.
"""
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from gozvision_agent.rag_service import (  # noqa: E402
    OPTOMETRY_DATA,
    SemanticKnowledgeBase,
)
from gozvision_agent.tools import (  # noqa: E402
    _resolve_patient_id,
    send_sos_alert,
    log_adherence_event,
    format_ehr_encounter_note,
)


class _FakeSession:
    def __init__(self, user_id):
        self.user_id = user_id


class _FakeInvocationContext:
    def __init__(self, user_id):
        self.session = _FakeSession(user_id)


class _FakeToolContext:
    def __init__(self, user_id):
        self.invocation_context = _FakeInvocationContext(user_id)


def test_corpus_integrity():
    assert "light sensitivity" in OPTOMETRY_DATA
    assert len(OPTOMETRY_DATA["light sensitivity"]["answer"]) > 10


def test_patient_id_from_session():
    assert _resolve_patient_id(_FakeToolContext("patient_abc")) == "patient_abc"


def test_patient_id_fallbacks():
    assert _resolve_patient_id(None) == "demo_patient_001"
    assert _resolve_patient_id(_FakeToolContext("")) == "demo_patient_001"
    assert _resolve_patient_id(object()) == "demo_patient_001"


def test_sos_stub_response_shape():
    result = send_sos_alert("User is lost", include_location=False, tool_context=None)
    assert result["status"] in ("sent", "stub")
    assert "SOS alert dispatched" in result["message"]


def test_singleton_identity():
    kb = SemanticKnowledgeBase()
    assert kb is SemanticKnowledgeBase()


def test_log_adherence_event():
    res = log_adherence_event("Latanoprost 0.005%", status="taken", tool_context=None)
    assert res["status"] == "recorded"
    assert res["medication"] == "Latanoprost 0.005%"
    assert res["patient_id"] == "demo_patient_001"


def test_format_ehr_encounter_note():
    sections = {
        "subjective": "Vision blurry right eye",
        "objective": "IOP 16 mmHg OU",
        "assessment": "Glaucoma stable",
        "plan": "Continue drops",
    }
    note = format_ehr_encounter_note(sections, patient_id="p123")
    assert "=== OPHTHALMIC CLINICAL ENCOUNTER NOTE ===" in note
    assert "IOP 16 mmHg OU" in note
    assert "p123" in note


if __name__ == "__main__":
    test_corpus_integrity()
    test_patient_id_from_session()
    test_patient_id_fallbacks()
    test_sos_stub_response_shape()
    test_singleton_identity()
    test_log_adherence_event()
    test_format_ehr_encounter_note()
    print("All GozVision agent tests passed.")

