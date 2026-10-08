# GozVision — Official Hackathon Product Feedback

> **Submission Ecosystem:** GozVision  
> **Evaluation Period:** October 2026  
> **Products Evaluated:** Model Context Protocol (MCP) / Alexa+ Tools, Ring APIs & Simulators, AWS Cloud Services (ECS Fargate, CloudFront, CodeBuild, Amplify, Bedrock).

---

## 1. Developer Tools, APIs, and SDKs Used

1. **Model Context Protocol (MCP) Python SDK & Alexa+ Agent Tools:**
   * Used for exposing clinical RAG retrieval, ambient EHR note drafting, emergency SOS alerting, drop adherence tracking, and Ring caretaking tools directly to voice agents and assistive orchestrators.
2. **Ring APIs & Device Simulator:**
   * Used for doorstep safety hazard inspection, visitor intercom voice announcements, and non-security nighttime wandering detection for low-vision patients.
3. **AWS ECS Fargate & AWS CodeBuild:**
   * Used for compiling and running the containerized GozVision backend with serverless reliability, automated zero-downtime task recycling, and least-privilege IAM roles.
4. **AWS CloudFront (SSL CDN):**
   * Used for global SSL termination (TLS 1.3), sub-second dynamic API routing, and eliminating browser mixed-content restrictions for the Flutter PWAs.
5. **AWS Amplify Hosting:**
   * Used for global CDN hosting of the Flutter Web Patient and Clinic Suite PWAs with custom single-page app rewrites.
6. **Amazon Bedrock Runtime & AgentCore (Claude 3.7 Sonnet / Amazon Nova Pro / Strands SDK):**
   * Used as the multi-service clinical fallback engine and cross-agent orchestrator for complex ophthalmic chart synthesis and drug interaction queries.

---

## 2. What Worked Well

* **MCP Tool Registration Ergonomics:**
  * The `@mcp.tool()` decorator syntax in Python allows lightning-fast tool exposure. Generating automatic JSON-schema parameter definitions directly from Python type hints and docstrings drastically reduced boilerplate.
* **AWS ECS Fargate Simplicity:**
  * Once the ECR repository and task definition were configured, ECS Fargate eliminated server maintenance entirely. Health-check integrations and automated container restarts provided zero-maintenance reliability.
* **AWS CloudFront Global Edge Latency:**
  * Serving API requests through CloudFront dramatically improved global round-trip latency, especially for audio and frame uploads from edge devices.
* **Ring Event Webhook Model:**
  * Ring's event classification (`ding`, `motion`, `door_open`) is well-structured and maps naturally to smart home caretaking event pipelines.

---

## 3. What Needs Work

* **Streamable HTTP Specification Documentation:**
  * Clear end-to-end documentation for running Streamable HTTP (spec version 2025-11-25) behind modern reverse proxies (CloudFront, Cloud Run, NGINX) was sparse. Standardizing reverse proxy headers (e.g. `X-Accel-Buffering: no`) in official guides would save developers hours of debugging.
* **Ring Instant Camera Frame Extraction:**
  * Accessing an immediate high-resolution keyframe from a Ring camera feed currently requires opening a full WebRTC/SIP video channel, introducing 1.5–3s latency. A dedicated "Assistive Snapshot API" providing a `<100ms` thumbnail upon motion/doorbell events is critical for low-vision fall prevention and doorstep navigation.
* **CloudFront Default SSE Buffering:**
  * CloudFront defaults to buffering streaming responses until 64KB is reached. For real-time conversational AI and agentic streaming, clear presets or CDK constructs for SSE/WebSocket passthrough are needed.

---

## 4. Onboarding Experience (Zero to Hello World)

* **MCP / Alexa+:**
  * **Rating: 8.5/10.** Getting a local stdio MCP server running took less than 15 minutes. Bridging it to Streamable HTTP required resolving MCP 2.x SDK structural changes, but once understood, the developer experience was clean and modular.
* **Ring API & Simulator:**
  * **Rating: 8/10.** Simulating doorbell and motion triggers was straightforward with event payloads. Setting up physical OAuth token refreshes required more manual coordination.
* **AWS Services (ECS, CloudFront, CodeBuild, Amplify):**
  * **Rating: 9/10.** AWS CodeBuild's Amazon Linux container build environment ran cleanly with Docker layer caching. Amplify connected seamlessly to GitHub for automated web deployments.

---

## 5. Would You Build With These Devices and Services Again?

* **Yes, absolutely.**
* **Why:**  
  The combination of **Amazon's voice & ambient home devices (Alexa+, Ring)** with **AWS's scalable cloud infrastructure (ECS, CloudFront, Bedrock)** provides the exact hardware-to-cloud continuum needed for healthcare accessibility. Assistive technology cannot rely on screens alone—visually impaired patients need ambient, audio-first, and camera-guided assistance that operates seamlessly in their homes and clinics. These tools make building enterprise-grade, life-saving ambient technology faster and more reliable than ever before.
