# CONTEXT.md — GozVision domain vocabulary

GozVision is an AI copilot platform for eye care. It serves two audiences at
once: **patients** (via Goz, the voice-first copilot) and **eye care clinics**
(via the Clinic Suite). This file defines the words the codebase uses so a
newcomer — human or AI — can navigate in one read.

## The two sides

- **Clinic** — a tenant of the platform: one practice (possibly multi-branch).
  Every record in the system belongs to exactly one clinic (`clinicId` is on
  every document). Clinics subscribe; clinics onboard their patients.
- **Practitioner** — an optometrist (or ophthalmologist) affiliated with a
  clinic. Prescribes devices, sees encounters, owns the clinical judgment.
- **Staff** — clinic roles that are not practitioners: front desk, technicians
  (pre-testing), optical dispensers, managers. RBAC distinguishes them.
- **Patient** — a person under a clinic's care, and the copilot's user. A
  patient may be clinic-prescribed (onboarded via the Clinic Suite) or
  self-serve (direct download, unaffiliated). See "Patient identity" below.
- **Caregiver** — a family member or aide linked to a patient. Receives SOS
  alerts, sees adherence summaries. May belong to no clinic.

## The Copilot Loop (inherited from GozAI, unchanged in spirit)

```
SENSES ──▶ CONTEXT ──▶ SESSION (Gemini Live) ──▶ INTENTS ──▶ ACTUATORS
                                                    │
                                                    ▼
                                            GROUNDING (ADK agents)
```

- **Sense** — input the copilot perceives unprompted: camera frames (1 FPS),
  mic audio, ambient light, screen capture, connectivity, battery.
- **Context pulse** — a silent message injected into the session; carries a
  **Tag** (`[SYSTEM - ...]`). Tags live in exactly one module
  (`SystemTags`); the prompt interpolates the same constants.
- **Session** — one live Gemini Live conversation. Knows the wire protocol;
  knows nothing about devices.
- **Intent** — something the model wants done in the world, expressed as a
  tool call and dispatched through the **CopilotDelegate** seam (one named
  interface; implemented by the SessionCoordinator).
- **Actuator** — haptics, flashlight, camera modes, Ghost Touch, SOS, memory.
- **Grounding** — character-accurate facts that constrain the model: offline
  OCR, product lookup, and the backend ADK agents' verified clinical RAG.
- **Mode** — Scene, Read, Screen (UI Navigator), Light.

## Clinic Suite modules

- **Low Vision Hub** — the module that closes the low-vision loop: referral
  tracking (who was referred, who attended), device prescription and trial
  records (**DeviceFit**), and **AdherenceSignal**s — usage and struggle data
  streamed from the copilot between visits. The core research insight: only
  ~64% of eligible patients get referred, ~55% attend, ~29% abandon devices
  within 3 months. Every Hub feature exists to shrink one of those leaks.
- **Front Desk** — scheduling, intake, verification, recall/no-show recovery.
- **Scribe** — ambient documentation: the exam conversation becomes the chart
  (draft for practitioner review, never auto-final).
- **Insights** — practice analytics: no-show rates, device abandonment,
  pre-test throughput.

## Shared clinical vocabulary

- **Encounter** — one clinical visit (exam, follow-up, device trial). The
  unit the Scribe documents and the Hub tracks.
- **Referral** — the hand-off from a general practitioner to low-vision
  rehabilitation services, with status (made / attended / lost).
- **DeviceFit** — a prescribed low-vision device (optical, electronic, or
  software — Goz itself is one), tied to a trial period and follow-ups.
- **AdherenceSignal** — a structured usage datapoint from the copilot (daily
  active use, task completions, detected struggles). The bridge between the
  two sides of the platform; always aggregated for clinic display, never
  session audio/video (zero media storage).
- **Alert** — an SOS document (inherited `sos_alerts` contract from GozAI).

## Patient identity

- Clinic-prescribed patient: authenticated account; `users/{uid}` carries
  `role: Patient`, `clinicId`, and their practitioner link.
- Self-serve patient: authenticated account with no clinic affiliation.
- Zero-UI demo flow: unauthenticated, falls back to the single demo patient
  id (`AppConfig.patientId` equivalent) so caregiver dashboards keep working.

## Decisions already made

- **Grounding over generation** for anything medical; the copilot never
  diagnoses. Clinical judgment belongs to the practitioner; Scribe output is
  a draft.
- **The prompt is data** (`system_prompt.dart` pattern): wording churns,
  structure lives in modules.
- **Intents are transport-agnostic** so new actuator hardware (Android
  AccessibilityService, smart glasses — see the GozAI native blueprint)
  plugs into the same CopilotDelegate.
- **Zero images/audio stored** by the copilot — adherence signals are
  structured data. Clinic Suite stores clinical records, not media.
- **Supabase (Postgres + RLS + Realtime)** is the data layer (ADR-0003):
  multi-tenant by clinic_id, policies in `supabase/migrations/`, backend
  writes via the service role, everything else through RLS.
