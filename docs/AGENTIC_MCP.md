# Model Context Protocol (MCP) & Alexa+ Integration

GozVision implements the **Model Context Protocol (MCP 2.x standard)** to allow external orchestrators, agentic assistants, and smart speaker platforms (such as **Amazon Alexa+**) to interact with the clinical platform over a standardized protocol.

---

## 1. Protocol Architecture (`backend/gozvision_mcp/server.py`)

* **Framework:** FastMCP / MCPServer (`mcp 2.2.0`).
* **Transport:** `stdio` (standard input/output) for local agent execution, containerized orchestration, and Alexa+ skill hosting.
* **Resilience:** Tools return structured dictionaries with error contexts; tools never raise unhandled exceptions to avoid breaking agent reasoning loops.

```
┌────────────────────────────────────────────────────────┐
│             External Agent Orchestrators               │
│        (Amazon Alexa+, Claude Desktop, LLMs)           │
└───────────────────────────┬────────────────────────────┘
                            │ Model Context Protocol (MCP)
                            ▼
┌────────────────────────────────────────────────────────┐
│             GozVision FastMCP Server                   │
├────────────────────────────────────────────────────────┤
│ • clinical_knowledge_lookup                            │
│ • trigger_emergency_sos                                │
│ • front_desk_recall_sweep                              │
│ • draft_ambient_scribe_chart                           │
│ • cv_enhance_accessibility_frame                       │
│ • smart_glasses_hud_process                            │
└───────────────────────────┬────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
    GozVision Agent Core         OpenCV 5 Engine
```

---

## 2. Tool Reference

### `clinical_knowledge_lookup(query: str)`
* **Description:** Retrieves grounded optometry guidance from the AAO, AOA, and WHO knowledge base using `gemini-embedding-2` vector similarity.
* **Input:** String query (e.g., *"light sensitivity in glaucoma"*).

### `trigger_emergency_sos(patient_id: str, message: str, ...)`
* **Description:** Dispatches an emergency alert to the patient's affiliated eye clinic and caregivers via Supabase Realtime.

### `front_desk_recall_sweep(clinic_id: str, horizon_days: int)`
* **Description:** Executes an autonomous audit of clinic appointments to identify unconfirmed visits, recent no-shows, and overdue annual check-ups.

### `draft_ambient_scribe_chart(encounter_id: str, transcript: str)`
* **Description:** Converts examination conversation dialogue into a structured SOAP clinical note draft.

### `cv_enhance_accessibility_frame(mode: str, frame_base64: str)`
* **Description:** Runs edge computer vision filters (`enhanced_contrast`, `glare_suppression`, `reading`) on an image frame.

### `smart_glasses_hud_process(device_model: str, battery_level_pct: int, ...)`
* **Description:** Generates an ultra-sparse transparent micro-OLED HUD overlay tailored for wearable devices like Ray-Ban Meta or Rokid Max.
