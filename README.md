# GozVision — The Enterprise AI Copilot & Practice Operating Platform for Eye Care

GozVision is an end-to-end, multi-tenant clinical intelligence and assistive visual copilot platform engineered for optometry and ophthalmology practices and their patients. It bridges in-clinic encounter efficiency with between-visit patient autonomy.

> "Clinical intelligence in the exam room. Visual autonomy in everyday life."

---

## Two Unified Portals, One Connected Ecosystem

| Dimension | **Goz Patient Copilot** (B2C) | **Goz Clinic Suite** (B2B) |
| :--- | :--- | :--- |
| **Target User** | Low-vision individuals, post-op patients, caregivers | Optometrists, ophthalmologists, clinical technicians, practice managers |
| **Core Capabilities** | • Dual-Mode: Low-Vision Assist (voice-first, fall prevention) & Clinic Companion (drops, appointments)<br/>• Plain-English accessible UI (WCAG 2.2 AAA contrast)<br/>• Edge OpenCV 5.0 video contrast filter & reading zone OCR<br/>• 1-tap optical reorders via Bachs instant checkout<br/>• Encrypted caregiver thread & 1-tap GPS SOS | • **Ambient Scribe Studio** with Optometric `OLD CARTS` Case History<br/>• **Physical Paper Form Digitizer** (AI layout analysis & replica)<br/>• **Dedicated EHR & FHIR R4 Hub** (Epic, Eyefinity, RevolutionEHR, ModMed)<br/>• **CMS RTM Billing Engine** (CPT 98975 / 98980 / 98981)<br/>• **Walk-In Reception POS Terminal** & Multi-Purpose Acrylic QR Signage<br/>• **Low Vision Hub** with 90-day device abandonment radar<br/>• **Air-Gapped Local WebGPU AI** vs. HIPAA BAA Cloud Switcher |
| **Surfaces** | Flutter PWA (Offline-ready) + iOS / Android | Flutter Web (PWA responsive) + Tablet / Desktop |

The clinical thesis: **the clinic suite distributes the copilot; the copilot generates continuous between-visit adherence and telemetry data no practice management system has ever possessed** — closing the documented low-vision referral leak (64% → 55%) and preventing the 29% 90-day assistive device abandonment rate.

---

## Monorepo Layout

```
gozvision/
├── apps/
│   ├── patient/                 # Goz Patient Copilot — Flutter PWA / Mobile (B2C)
│   ├── clinic/                  # Goz Clinic Suite — Full Practice Management Hub (B2B)
│   └── website/                 # Landing Page & Interactive Viewfinder Simulator
├── packages/
│   ├── copilot_core/            # Copilot Loop: State machines, telemetry, audio session coordinator
│   ├── design_system/           # High-contrast accessible design system (AAA WCAG 2.2 compliant)
│   ├── domain/                  # Shared models: Patient, Encounter, DeviceFit, RTM Billing, Storefront
│   └── api_client/              # Typed multi-tenant client for Supabase & backend agent services
├── supabase/
│   └── migrations/              # PostgreSQL schema, Row-Level Security (RLS), and realtime subscriptions
├── backend/
│   ├── gozvision_agent/         # Agentic services: clinical RAG, recall outreach, ambient Scribe
│   ├── gozvision_vision/        # OpenCV 5.0 edge CV contrast & reading zone pipeline
│   ├── gozvision_mcp/           # FastMCP server exposing clinical tools to external agent runtimes
│   ├── deploy.sh                # Cloud Run container deployment
│   ├── seed_clinic_demo.py      # Seeds realistic clinic demo data (patients, encounters, fittings)
│   └── test_*.py                # Comprehensive test suites
└── docs/
    ├── ARCHITECTURE.md          # Enterprise System Topography, FHIR R4 mappings, RTM billing, security
    ├── DATA_MODEL.md            # Multi-tenant PostgreSQL data models & RLS policies
    └── adr/                     # Architectural Decision Records
```

---

## Clinic Suite Quick Start

```bash
# 1. Initialize Supabase Database Schema
#    Apply supabase/migrations/0001_initial_schema.sql to your Supabase project.

# 2. Seed the Clinical Demo World
cd backend
python seed_clinic_demo.py

# 3. Launch the Goz Clinic Suite (Web)
cd ../apps/clinic
flutter run -d chrome    # Sign in with: practitioner@gozvision.demo / gozvision-demo

# 4. Launch the Goz Patient Copilot (PWA / Mobile)
cd ../apps/patient
flutter run -d chrome    # Or flutter run -d ios / android
```

---

## Technical Stack & Certifications

- **Frontend & App Framework**: Flutter 3.47 stable / Dart 3.13 (PWA-first, compiled to WebAssembly / CanvasKit)
- **Database & Multi-Tenancy**: Supabase PostgreSQL 16 with cryptographic Row-Level Security (`clinic_id` isolation), PostGIS geolocation, and Realtime WebSocket streams.
- **Interoperability Standard**: HL7 FHIR Release 4 & ONC USCDI v3 (SMART on FHIR OAuth 2.0 PKCE) for Epic Systems, Eyefinity EHR, RevolutionEHR, ModMed EMA, and Compulink Advantage.
- **Payment & Practice Commerce**: Dual-rail architecture via Bachs E-Commerce API (FedNow / RTP instant bank payouts) and Stripe Connect multi-tenant terminal routing.
- **Edge Computer Vision**: OpenCV 5.0 edge pipeline (Adaptive LAB CLAHE contrast, specular glare attenuation, morphological reading zone text isolation).
- **AI Processing Sovereignty**: Runtime toggle between **Cloud AI Engine** (Google Cloud Vertex AI / OpenAI under signed HIPAA Business Associate Agreement with zero data retention) and **Air-Gapped Local AI** (100% on-device WebGPU / ONNX Runtime Web with zero network egress).
- **Coding & Billing Standards**: LOINC, SNOMED CT, ICD-10-CM, and CMS Remote Therapeutic Monitoring (CPT 98975, 98980, 98981).
