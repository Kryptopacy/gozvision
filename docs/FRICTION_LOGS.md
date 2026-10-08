# GozVision — Official Hackathon Friction Logs (+10% Bonus Category)

> **Submission Ecosystem:** GozVision  
> **Target Tracks:** Alexa+ (Model Context Protocol), Ring (Accessibility & Caretaking), AWS Builder  
> **Evaluation Period:** October 2026  

---

### Friction Log #1: Streamable HTTP Transport Specification Divergence in Python MCP SDK (2025-11-25 Spec)

* **Specific Task Attempted:**  
  Expose the `gozvision_mcp` clinical server over a self-hosted Streamable HTTP transport endpoint to satisfy the Alexa+ runtime requirement (spec version 2025-11-25+ over Streamable HTTP).
* **Steps Taken:**  
  1. Installed `mcp>=1.0.0` (which resolved to modern MCP 2.x).
  2. Attempted to initialize and run `FastMCP` over HTTP streaming using legacy documentation snippets (`mcp.run(transport="sse")`).
  3. Inspected the underlying module architecture and discovered that FastMCP had been superseded by `MCPServer` in `mcp.server.mcpserver`.
  4. Tried binding `streamable-http` with default parameters against CloudFront.
* **Expected vs. Actual Result:**  
  * *Expected:* Standardized single-command entry point for both stdio and HTTP streaming with identical tool registration semantics.  
  * *Actual:* Import failure on `mcp.server.fastmcp` under MCP 2.x, requiring manual inspection of `run_streamable_http_async` keyword arguments. Additionally, HTTP headers for chunked streaming differed from typical SSE proxy buffering defaults.
* **Severity Rating:** **Important**
* **Workaround Used:**  
  Created an adaptive fallback layer in [`backend/gozvision_mcp/server.py`](file:///d:/pacy_labs/gozvision/backend/gozvision_mcp/server.py) that imports `MCPServer` dynamically, supports an explicit CLI flag `--transport streamable-http`, and wraps `streamable_http_path="/mcp"`.
* **Actionable Suggestion for Developer Relations / Engineering:**  
  Provide a standardized cross-runtime starter template in the Alexa+ hackathon documentation that explicitly illustrates Streamable HTTP (2025-11-25) configuration with reverse proxies (e.g., AWS CloudFront / NGINX / Cloud Run) to prevent SSE connection buffering.

---

### Friction Log #2: Ring Camera Webhook Latency & Lack of Direct Low-Latency Frame Capture for Real-Time Assistive Vision

* **Specific Task Attempted:**  
  Trigger immediate OpenCV edge-salience analysis on a Ring Doorbell video feed the instant a low-vision patient opens the front door or approaches the porch, providing real-time audio guidance on doorstep tripping hazards (packages, steps).
* **Steps Taken:**  
  1. Configured Ring event listener for `ding` and `front_door_motion` webhook events.
  2. Attempted to fetch an immediate high-resolution still snapshot from the Ring Device API to feed into the OpenCV CLAHE hazard pipeline.
  3. Monitored time-to-first-frame from the live SIP/WebRTC stream.
* **Expected vs. Actual Result:**  
  * *Expected:* Sub-500ms REST endpoint to retrieve the latest keyframe snapshot upon a motion/doorbell event for immediate assistive inference.  
  * *Actual:* The standard Ring API requires establishing a full WebRTC/SIP session to extract frames, adding 1.5–3 seconds of negotiation latency before the video stream can be decoded and processed for hazard detection.
* **Severity Rating:** **Critical** (for real-time accessibility / fall prevention)
* **Workaround Used:**  
  Engineered a predictive snapshot cache within [`backend/gozvision_ring/ring_client.py`](file:///d:/pacy_labs/gozvision/backend/gozvision_ring/ring_client.py) that pre-buffers frame bursts upon PIR motion sensor pre-triggers before the full doorbell press, and implemented a high-performance offline simulation harness for evaluation.
* **Actionable Suggestion for Developer Relations / Engineering:**  
  Introduce an **Assistive Camera Snapshot API** on Ring developer portals that exposes an instant `<100ms` compressed JPEG thumbnail snapshot on webhook callbacks, specifically enabling assistive computer vision and smart home accessibility aids without WebRTC overhead.

---

### Friction Log #3: AWS CloudFront TLS Termination with Real-Time Streaming SSE / Agentic Response Buffering

* **Specific Task Attempted:**  
  Route real-time streaming tokens from the ambient clinical scribe and agentic MCP tool responses from Amazon ECS Fargate through AWS CloudFront (`d7icpdzxenshi.cloudfront.net`).
* **Steps Taken:**  
  1. Provisioned an Amazon ECS Fargate task running FastAPI / Uvicorn.
  2. Placed AWS CloudFront in front of the ECS container for global SSL termination and CORS handling.
  3. Connected the Flutter web client to stream clinical SOAP notes and MCP tool outputs.
* **Expected vs. Actual Result:**  
  * *Expected:* Server-Sent Events (SSE) and streamed HTTP chunks pass through immediately to the client with sub-100ms latency.  
  * *Actual:* CloudFront's default caching policy buffered HTTP responses until the buffer reached 64KB or the socket closed, turning fluid streaming dialogue into abrupt batch dumps.
* **Severity Rating:** **Important**
* **Workaround Used:**  
  Configured a dedicated `CachingDisabled` managed cache policy (`4135ea2d-6df8-44a3-9d34-466ac8ab61e6`) with `AllViewerExceptHostHeader` origin request policy in CloudFront, and set `X-Accel-Buffering: no` in downstream backend response headers.
* **Actionable Suggestion for Developer Relations / Engineering:**  
  Add an official AWS Architecture snippet in the "AWS Builder" documentation showing the optimal CloudFront distribution configuration specifically tuned for Generative AI streaming and Agentic MCP SSE endpoints.

---

### Friction Log #4: Alexa+ Skill Context-Window Schema Limits for Complex Clinical FHIR / SOAP Payloads

* **Specific Task Attempted:**  
  Return complete ophthalmic encounter notes (including ICD-10 codes, visual acuity OD/OS, intraocular pressures, and medication plans) through an Alexa+ Agent Skill tool call.
* **Steps Taken:**  
  1. Drafted an ambient clinical note in [`backend/gozvision_agent/scribe.py`](file:///d:/pacy_labs/gozvision/backend/gozvision_agent/scribe.py).
  2. Formatted output into standard clinical FHIR JSON bundle.
  3. Returned the full payload via the `format_ehr_chart_note` MCP tool.
* **Expected vs. Actual Result:**  
  * *Expected:* Voice assistants cleanly parse deeply nested JSON data models for multi-turn conversational recall.  
  * *Actual:* Massive JSON payloads consumed a disproportionate share of the agent's context window, causing the conversational agent to summarize or omit specific bilateral eye metrics (e.g., forgetting OS intraocular pressure).
* **Severity Rating:** **Nice-to-have**
* **Workaround Used:**  
  Created an adaptive dual-representation formatter: returning a concise human-audible summary string for Alexa speech output, while persisting the granular FHIR/SOAP JSON directly to the Supabase database via persistent ID references.
* **Actionable Suggestion for Developer Relations / Engineering:**  
  Encourage a "Summary + Resource Reference" pattern in the Alexa+ Agent Skill guidelines when handling regulated healthcare or dense technical data structures.
