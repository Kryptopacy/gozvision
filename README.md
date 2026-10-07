# GozVision — the AI copilot platform for eye care clinics

GozVision is an end-to-end patient–optometrist platform: **Goz**, the empathetic
voice-first copilot patients use for daily visual assistance, prescribed by
the clinic and wrapped in the clinic workflow tools optometrists actually need.

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
├── supabase/
│   └── migrations/        # Postgres schema + RLS policies (ADR-0003)
├── backend/
│   ├── gozvision_agent/   # Agentic services: clinical RAG, recall outreach, ambient Scribe
│   ├── deploy.sh          # Cloud Run deployment
│   ├── seed_clinic_demo.py# Seeds a full demo clinic world (auth users + data)
│   └── test_*.py          # Offline test suites (no API keys needed)
└── docs/
    ├── DATA_MODEL.md      # Multi-tenant data model
    └── adr/               # Architecture decision records
```

## Clinic Suite quick start

```bash
# 1. Create the schema (once): paste supabase/migrations/0001_initial_schema.sql
#    into the Supabase dashboard SQL editor — or `supabase db push` after linking.

# 2. Seed the demo world (reads SUPABASE_URL + SUPABASE_SERVICE_KEY from backend/.env)
cd backend && python seed_clinic_demo.py

# 3. Run the recall sweep — reminders, no-show recovery, annual recalls
python -m gozvision_agent.recall --clinic demo_clinic_001

# 4. Draft a scribe chart (or ask the agent: "draft the chart for enc_1")
python -m gozvision_agent.scribe enc_1

# 5. Run the Clinic Suite and sign in (password: gozvision-demo)
cd ../apps/clinic && flutter run -d chrome    # practitioner@gozvision.demo
```

## Stack (current as of 2026-10)

- **Flutter 3.47 stable / Dart 3.13** — PWA-first, mobile-ready
- **Supabase**: Auth (RBAC), Postgres + RLS (multi-tenant clinic + copilot data), Realtime streams
- **Agentic Engine & Vision Pipeline**: Python 3.13 backend / Cloud Run / AWS, OpenCV visual enhancement, MCP server & voice interface
- **Embeddings**: `gemini-embedding-001`
