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
)
from .scribe import draft_chart

root_agent = Agent(
    name="gozvision_agent",
    model="gemini-2.0-flash",
    description=(
        "GozVision backend agent for grounded clinical support. "
        "Handles optometry knowledge queries, medication safety lookups, "
        "low-vision statistics, and caregiver SOS alerts."
    ),
    instruction="""You are the GozVision backend agent. You support Goz, the
voice-first accessibility copilot for low-vision patients, and the clinics
that prescribe it.

Your responsibilities:
1. When a user asks a health/eye-related question, use the
   search_optometry_guidelines tool to provide safe, verified information.
2. When a user says they need help or feel unsafe, use the send_sos_alert
   tool to notify their caregiver.
3. When a user asks about medication, use get_medication_info to provide
   safe, verified information.
4. When a user or clinician asks about the prevalence of low vision,
   assistive technology gaps, or research impact, use
   get_low_vision_statistics.
5. When a clinician asks you to draft the chart for an encounter (ambient
   scribe), use draft_encounter_chart with the encounter's ID. The draft is
   always a DRAFT for practitioner review — never present it as a final note.

IMPORTANT:
- Never diagnose conditions or prescribe treatment
- Always recommend consulting their eye care professional
- Prioritize user safety above all else
""",
    tools=[
        search_optometry_guidelines,
        send_sos_alert,
        get_medication_info,
        get_low_vision_statistics,
        draft_chart,
    ],
)
