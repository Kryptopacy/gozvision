# Extraction plan — GozAI → GozVision

The GozAI repo (hackathon submission) is **frozen as-is** — it remains the
challenge artifact. GozVision is a new app in a new repo. This document says
what ports, what adapts, and what is built fresh.

## Ports (verified green in GozAI on Flutter 3.47 / Dart 3.13, 2026-10)

| GozAI asset | Destination | Effort |
|---|---|---|
| `lib/core/copilot/gozai_session_types.dart` | `packages/copilot_core/lib/` | Verbatim |
| `lib/core/copilot/copilot_delegate.dart` | `packages/copilot_core/lib/` | Verbatim |
| `lib/core/copilot/system_tags.dart` | `packages/copilot_core/lib/` | Verbatim |
| `lib/services/session_coordinator.dart` | `packages/copilot_core/lib/src/` | Adapt: constructor takes abstract service interfaces (defined in `copilot_core`), not concrete GozAI services |
| `lib/core/system_prompt.dart` | `apps/patient/lib/core/` | Verbatim start; grows per-mode clinic addenda |
| `lib/services/user_identity_service.dart` | `packages/copilot_core/lib/` | Adapt: `clinicId` awareness added |
| `lib/services/gemini_live_service.dart` | `packages/copilot_core/lib/src/` | Verbatim start (transport + tool registry) |
| `backend/gozai_agent/clinical_corpus.py` | `backend/agents/` | **Ported already** (first commit) |
| `backend/gozai_agent/rag_service.py` | `backend/agents/` | **Ported already** (first commit; `gemini-embedding-001`) |
| SOS contract (`sos_service.dart` + backend `send_sos_alert` w/ `tool_context`) | `packages/copilot_core/` + `backend/agents/` | Port schema as-is; add clinic scoping to the alert document |
| firestore.rules patterns | `backend/` | Restart from multi-tenant rules (clinicId-scoped) |

## Built fresh (the redesign)

- **`apps/patient/`** — new shell, new branding, same Copilot Loop spine.
  The GozAI screens served a hackathon demo; the patient app gets the
  premium accessible design system from day one.
- **`apps/clinic/`** — the entire B2B suite (Low Vision Hub, Front Desk,
  Scribe, Insights). Nothing to port: GozAI's dashboards were demo-grade.
- **`packages/design_system/`** — one kit, two themes: the accessible B2C
  theme (high contrast, large targets, TalkBack/VoiceOver first) and the
  professional B2B theme (obsidian/malachite lineage from the GozAI
  dashboards, matured).
- **`packages/domain/` + `packages/api_client/`** — multi-tenant models
  (see DATA_MODEL.md).
- **`backend/api/`** — clinic API (appointments, referrals, device fits,
  adherence aggregation). The ADK agents keep the RAG grounding role.

## The one structural change copilot_core needs

In GozAI, `SessionCoordinator` depended on 11 concrete service classes. For
the package to be shared between `apps/patient` (and later embedded views in
`apps/clinic`), its constructor must accept **interfaces** (`CameraSense`,
`AudioIO`, `ActuatorHub`, `MemoryStore`, `AlertSink`, ...) defined inside
`copilot_core`, with the concrete Flutter implementations living in the app.
This is the same deepening move as the original CopilotDelegate extraction —
one seam, two adapters (device app / clinic embed).

## Method

Copy files (no git history grafting — the histories stay separate by design:
GozAI is the frozen artifact, GozVision is the new lineage). Every ported
file keeps its tests; the tag-contract tests move with `system_prompt` and
`SystemTags`.
