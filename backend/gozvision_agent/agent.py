"""GozVision ADK agent — backend orchestrator for grounded clinical answers.

Deployed on Google Cloud Run (`adk api_server --port 8080 gozvision_agent`).
The Goz copilot delegates specialized medical and statistical queries here
through the identity-stamped `/run` contract (see apps/patient
AdkBridgeService): every invocation carries the patient's identity in the
ADK session so safety-critical writes (SOS alerts) land on the right record.
"""
import os

from dotenv import load_dotenv
from google.adk import Agent

# Load environment variables from the repo-root .env when running locally.
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", "..", ".env"))

from .tools import (
    get_low_vision_statistics,
    get_medication_info,
    search_optometry_guidelines,
    send_sos_alert,
    log_adherence_event,
    format_ehr_encounter_note,
    find_clinics,
    get_clinic_schedule_and_hours,
    book_clinic_appointment,
    schedule_doctor_followup,
)
from .scribe import draft_chart

root_agent = Agent(
    name="gozvision_agent",
    model="gemini-flash-latest",
    description=(
        "GozVision backend clinical agent. Handles optometry knowledge queries, "
        "medication safety lookups, drop adherence logging, low-vision statistics, "
        "clinic discovery, working hours lookup, appointment booking, doctor follow-ups, "
        "EHR chart note formatting, and caregiver SOS alerts."
    ),
    instruction="""You are the GozVision backend clinical agent. You support both low-vision
accessibility patients and general eye clinic patients across the continuum of optometric care,
as well as the clinicians and practices who care for them.

Your responsibilities:
1. When a user asks an eye health or vision question, use search_optometry_guidelines to provide safe, verified clinical guidance.
2. When a user says they need help, are lost, or feel unsafe, use send_sos_alert to notify their caregiver or clinic.
3. When a user asks about an eye drop or medication, use get_medication_info.
4. When a user asks to find an eye clinic or optometry practice, use find_clinics.
5. When a user asks for clinic hours, doctors on duty, or availability, use get_clinic_schedule_and_hours.
6. When a user wants to book an eye exam or device trial, use book_clinic_appointment.
7. When a clinician or doctor wants to schedule a follow-up or recall check-in, use schedule_doctor_followup.
8. When a patient reports taking their prescribed drops (e.g. Latanoprost, Systane), use log_adherence_event to record their compliance streak.
9. When a clinician or user asks about low-vision prevalence or clinical statistics, use get_low_vision_statistics.
10. When a clinician asks to draft the encounter SOAP chart (ambient scribe), use draft_chart.
11. When a clinician requests EHR export formatting for Epic, Eyefinity, or RevolutionEHR, use format_ehr_encounter_note.

IMPORTANT:
- Never diagnose conditions or prescribe treatment autonomously.
- Always recommend consulting their eye care professional for personalized medical advice.
- Prioritize patient safety and clinical grounding above all else.
""",
    tools=[
        search_optometry_guidelines,
        send_sos_alert,
        get_medication_info,
        log_adherence_event,
        get_low_vision_statistics,
        draft_chart,
        format_ehr_encounter_note,
        find_clinics,
        get_clinic_schedule_and_hours,
        book_clinic_appointment,
        schedule_doctor_followup,
    ],
)
