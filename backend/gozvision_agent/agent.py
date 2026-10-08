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
    create_product_checkout,
    get_clinic_balances,
    execute_clinic_payout,
    handle_bachs_webhook,
    check_patient_recall_and_refills,
    inspect_ring_doorstep_safety,
    triage_ring_caretaker_event,
    announce_ring_intercom_message,
)
from .scribe import draft_chart

root_agent = Agent(
    name="gozvision_agent",
    model="gemini-flash-latest",
    description=(
        "GozVision backend clinical agent. Handles optometry knowledge queries, "
        "medication safety lookups, drop adherence logging, low-vision statistics, "
        "clinic discovery, working hours lookup, appointment booking, doctor follow-ups, "
        "EHR chart note formatting, caregiver SOS alerts, optical dispensary checkout "
        "session creation (Bachs), clinic balance enquiries, payout initiation, "
        "patient lifecycle annual exam recalls and drop refill checks, and "
        "Ring smart doorbell/camera caretaking and doorstep accessibility hazard inspection."
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
12. When a clinician or patient wants to purchase an optical product (frames, lenses, drops), use create_product_checkout to generate a Bachs checkout URL.
13. When a clinic operator asks about their payment balance or revenue, use get_clinic_balances.
14. When a clinic operator wants to send funds to their bank account, use execute_clinic_payout with the destination_id and amount.
15. When a patient asks when their next annual eye exam is due or if their eye drops need a refill, use check_patient_recall_and_refills.
16. When checking if the doorstep or porch has tripping hazards or packages for a low-vision patient, use inspect_ring_doorstep_safety.
17. When reviewing Ring doorbell or motion events for nighttime wandering or caregiver alerts, use triage_ring_caretaker_event.
18. When broadcasting spoken audio or announcements over Ring Chime or connected speakers, use announce_ring_intercom_message.

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
        create_product_checkout,
        get_clinic_balances,
        execute_clinic_payout,
        handle_bachs_webhook,
        check_patient_recall_and_refills,
        inspect_ring_doorstep_safety,
        triage_ring_caretaker_event,
        announce_ring_intercom_message,
    ],
)
