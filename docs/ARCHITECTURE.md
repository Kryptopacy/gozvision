# GozVision Architecture & Hackathon Specification

GozVision is an assistive visual copilot and clinical workflow automation platform engineered for low-vision patients and eye care practices.

```mermaid
flowchart TB
    subgraph ClientSurfaces["Client Surfaces"]
        B2C["Patient Copilot (Flutter PWA / Mobile)<br/>• Eyes-and-hands voice assistant<br/>• Real-time OpenCV video filter<br/>• SOS Emergency trigger"]
        B2B["Goz Clinic Suite (Flutter Web)<br/>• Low Vision Hub & Device Fits<br/>• Front Desk Scheduling & Recall<br/>• Ambient Scribe Dashboard<br/>• Practice Insights"]
    end

    subgraph EdgeVision["Computer Vision Engine (OpenCV 5.0)"]
        CV_Contrast["Adaptive CLAHE Contrast + Edge Overlay<br/>(Macular Degeneration & AMD)"]
        CV_Glare["Specular Glare Attenuation<br/>(Cataracts & Photophobia)"]
        CV_Text["Morphological Reading Zone Detection<br/>(Targeted Magnification)"]
    end

    subgraph AgenticCore["Agentic & Protocol Layer"]
        MCP["Model Context Protocol (FastMCP / MCPServer)<br/>• Port: stdio / SSE<br/>• Alexa+ Agent Skills Interface<br/>• Tooling Seams"]
        RAG["Clinical Knowledge Retrieval (RAG)<br/>• AAO, AOA & WHO guidelines<br/>• Embeddings: gemini-embedding-001"]
        SCRIBE["Ambient Scribe Engine<br/>• SOAP clinical draft generation"]
        RECALL["Front Desk Recall Engine<br/>• Worklist generator & no-show recovery"]
    end

    subgraph DataCloud["Cloud & Persistence Layer"]
        SUPABASE["Supabase (PostgreSQL + RLS + Realtime)<br/>• Clinic multi-tenancy<br/>• Appointments & Encounters<br/>• Adherence signals & SOS state"]
        AWS_STAGING["AWS Cloud Services (AWS Builder Track)<br/>• Amazon S3 (Scans & Assets)<br/>• Amazon SES (Clinical Care Summaries)<br/>• AWS Lambda / App Runner Container"]
    end

    B2C -->|Camera Frames| EdgeVision
    EdgeVision -->|Enhanced View| B2C
    B2C -->|Voice / Tool Calls| MCP
    B2B -->|Encounter Audio / Transcripts| SCRIBE
    MCP --> RAG
    MCP --> SCRIBE
    MCP --> RECALL
    SCRIBE --> SUPABASE
    RECALL --> SUPABASE
    B2C -->|Realtime Alerts| SUPABASE
    B2B -->|Clinician Queries| SUPABASE
    SCRIBE -.->|Outreach / Reports| AWS_STAGING
```

---

## Hackathon Track Alignments

### 1. Amazon Developer Hackathon: Build, Ship, Shape (Deadline: Oct 23, 2026)
* **Track:** **Alexa+ Track** (Agentic experiences, Agent Skills, and self-hosted MCP servers).
* **Mini-Challenges:** **AWS Builder** & **Open Source** challenges.
* **Component:** `backend/gozvision_mcp/server.py` exposing:
  - `clinical_knowledge_lookup`
  - `trigger_emergency_sos`
  - `front_desk_recall_sweep`
  - `draft_ambient_scribe_chart`
  - `cv_enhance_accessibility_frame`

### 2. OpenCV AI Competition 2026 (Deadline: Oct 26, 2026)
* **Track:** **Healthcare & Accessibility** and **Agentic Vision Award**.
* **Component:** `backend/gozvision_vision/cv_pipeline.py` implementing:
  - `enhanced_contrast`: LAB CLAHE + Canny morphological boundaries for AMD patients.
  - `glare_suppression`: Specular highlight attenuation for cataracts/photophobia.
  - `reading`: Text detection via morphological gradient bounding boxes.
