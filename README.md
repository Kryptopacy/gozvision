# GozVision — the AI copilot platform for eye care clinics

GozVision expands the GozAI low-vision copilot into a full patient–optometrist
platform: **Goz**, the empathetic voice-first copilot patients already know,
prescribed by the clinic and wrapped in the clinic workflow tools optometrists
actually need.

> "GozVision — the AI copilot platform for eye care clinics."

## Two products, one platform

| | **Goz Copilot** (B2C) | **Goz Clinic Suite** (B2B) |
|---|---|---|
| Who | Low-vision patients + their caregivers | Optometrists, clinic owners, staff |
| What | Eyes-and-hands copilot: scene awareness, reading, UI navigation, SOS | Low Vision Hub, Front Desk, Scribe, Insights |
| Surfaces | Flutter PWA + mobile | Flutter web |

The platform thesis: **the clinic suite distributes the copilot; the copilot
generates the between-visit adherence data no practice-management system has
ever had** — closing the low-vision loop (referral → device fit → sustained
use) that leaks patients at every step today.

## Monorepo layout

```
gozvision/
├── apps/
│   ├── patient/           # Goz Copilot — Flutter PWA + mobile (B2C)
│   └── clinic/            # Goz Clinic Suite — Flutter web (B2B)
├── packages/
│   ├── copilot_core/      # Copilot Loop: CopilotDelegate, SessionCoordinator, SystemTags
│   ├── design_system/     # One UI kit: accessible B2C theme + professional B2B theme
│   ├── domain/            # Shared models: Clinic, Patient, Encounter, DeviceFit, ...
│   └── api_client/        # Typed backend client
├── backend/
│   ├── agents/            # ADK agents (clinical RAG grounded — ported from GozAI)
│   └── api/               # Multi-tenant clinic API (planned)
└── docs/
    ├── DATA_MODEL.md      # Multi-tenant data model
    ├── EXTRACTION.md      # What ports from GozAI vs. what is rebuilt
    └── adr/               # Architecture decision records
```

## Stack (current as of 2026-10)

- **Flutter 3.47 stable / Dart 3.13** — PWA-first, mobile-ready
- **Firebase**: Auth (RBAC), Firestore (realtime copilot + clinic data, v1)
- **Google ADK 1.26** on Cloud Run — grounded clinical agents (`POST /run` contract)
- **Embeddings**: `gemini-embedding-001` (text-embedding-004 is retired and 404s)
- Node 22 LTS / Python 3.13 for the agent runtime

## Provenance

Extracted from the [GozAI](https://github.com/Kryptopacy/GozAI) hackathon
submission (Gemini Live Agent Challenge). See [docs/EXTRACTION.md](docs/EXTRACTION.md).
