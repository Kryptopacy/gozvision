# GozVision Documentation Hub

Welcome to the GozVision technical and clinical documentation index. 
GozVision is an assistive visual copilot and clinical intelligence platform designed for all eye care patients, with first-class assistance for low-vision individuals.

---

## 📚 Documentation Directory

```
docs/
├── ARCHITECTURE.md          # End-to-end system topology & hackathon track alignments
├── DATA_MODEL.md            # Multi-tenant Postgres/Supabase schemas, RLS & data contracts
├── CLINICAL_SCRIBE.md       # Ambient SOAP scribe, clinical guardrails & Linked Evidence audit
├── VISION_PIPELINE.md       # OpenCV 5.0 contrast, glare suppression & smart glasses telemetry
├── AGENTIC_MCP.md           # Model Context Protocol (FastMCP/MCPServer) & Alexa+ integration
├── RECALL_MESSAGING.md      # Front desk recall engine & AWS End User Messaging (WhatsApp/SMS)
└── adr/                     # Architecture Decision Records
    ├── 0002-firestore-first-v1.md
    ├── 0003-supabase-data-layer.md
    └── 0004-model-context-protocol-and-wearables.md
```

---

## 📑 Core Guides

### 1. [System Architecture & Topology](ARCHITECTURE.md)
* High-level architectural diagram (Mermaid).
* Breakdown of Client Surfaces (Flutter B2C/B2B), Computer Vision Engine (OpenCV 5.0), Agentic MCP Core, and Cloud Persistence (Supabase + AWS).
* Alignment with **Amazon Developer Hackathon** (Alexa+ Track) and **OpenCV AI Competition 2026**.

### 2. [Multi-Tenant Data Model & Security](DATA_MODEL.md)
* Tenancy design via `clinic_id` scoping and PostgreSQL Row-Level Security (RLS).
* Tables: `clinics`, `profiles`, `patients`, `appointments`, `encounters`, `device_fits`, `adherence_signals`, `conversations`, and `messages`.
* Role-based access control (RBAC): Owner, Practitioner, Staff, Patient, and Caregiver.

### 3. [Ambient Clinical Scribe & Linked Evidence](CLINICAL_SCRIBE.md)
* Grounding over generation: why the scribe strictly drafts and never auto-finalizes.
* The 4 SOAP sections: Subjective, Objective, Assessment, Plan.
* **Linked Evidence**: Abridge-style verification allowing clinicians to cross-reference extracted metrics (IOP, visual acuity) directly against raw encounter transcripts.

### 4. [Computer Vision & Wearable Profile](VISION_PIPELINE.md)
* Real-time OpenCV 5.0 algorithmic filters:
  * **Adaptive CLAHE Contrast & Canny Edge Overlay:** Spatial cues for macular degeneration.
  * **Specular Glare Attenuation:** Highlight suppression for cataracts and photophobia.
  * **Reading Zone Detection:** Morphological gradient text segmentation.
* **Smart Glasses Telemetry Profile:** Ultra-sparse transparent micro-OLED HUD for Ray-Ban Meta, Rokid Max, and Even Realities G1, with IMU head-tilt hazard warning.

### 5. [Model Context Protocol (MCP) & Alexa+ Integration](AGENTIC_MCP.md)
* MCP standard implementation (`MCPServer` over `stdio` transport).
* Full tool catalog: `clinical_knowledge_lookup`, `trigger_emergency_sos`, `front_desk_recall_sweep`, `draft_ambient_scribe_chart`, `cv_enhance_accessibility_frame`, and `smart_glasses_hud_process`.

### 6. [Front Desk Recall & Conversational Scheduling](RECALL_MESSAGING.md)
* Autonomous recall sweep for unconfirmed appointments, recent no-shows, and annual routine check-ups.
* Two-way patient rescheduling over WhatsApp and SMS using **AWS End User Messaging** (`boto3 socialmessaging` & `pinpoint-sms-voice-v2`).
* In-app care threads connecting practitioners, patients, and caregivers with push and email notifications.

---

## 🏛️ Architecture Decision Records (ADRs)
* [ADR-0002: Firestore-First Data Layer (Superseded)](adr/0002-firestore-first-v1.md)
* [ADR-0003: Supabase Postgres Data Layer](adr/0003-supabase-data-layer.md)
* [ADR-0004: Standardizing on MCP, OpenCV 5, and Wearables](adr/0004-model-context-protocol-and-wearables.md)
