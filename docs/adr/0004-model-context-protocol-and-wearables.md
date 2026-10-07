# ADR-0004: Standardizing on Model Context Protocol (MCP), OpenCV 5.0, and Wearables

Date: 2026-10-07 · Status: Accepted

## Context

GozVision expanded from a standalone voice assistant into an ecosystem serving all eye care patients (with low-vision assistance as a first-class citizen) and optometrists. 
To compete globally and qualify for leading developer hackathons (Amazon Developer Hackathon, OpenCV AI Competition 2026), the platform needed:
1. An open agent protocol compatible with Amazon Alexa+ and external agentic frameworks.
2. A deterministic, low-latency edge computer vision pipeline that doesn't violate patient privacy by streaming continuous video to external clouds.
3. Support for emerging optical see-through smart glasses (e.g. Ray-Ban Meta, Rokid Max).

## Decision

1. **Standardize on MCP 2.x:** Implement a FastMCP / MCPServer (`backend/gozvision_mcp/server.py`) exposing the platform's clinical RAG, emergency SOS, recall engine, and scribe capabilities over `stdio`.
2. **OpenCV 5.0 Edge Vision Pipeline:** Implement localized computer vision algorithms (`backend/gozvision_vision/cv_pipeline.py`) using CLAHE LAB contrast, Canny edge detection, glare suppression, and morphological text segmentation.
3. **Smart Glasses HUD Profile:** Create specialized wearable profiles (`smart_glasses.py`) that render ultra-sparse micro-OLED overlays and use IMU head-tilt telemetry for hazard detection.
4. **Linked Evidence Scribe:** Adopt Abridge-style evidence linking in the clinic UI (`scribe_page.dart`), allowing clinicians to click any SOAP finding and inspect the source transcript.
5. **AWS End User Messaging Integration:** Add two-way conversational scheduling for WhatsApp and SMS (`recall.py`) using native AWS SDKs (`socialmessaging` and `pinpoint-sms-voice-v2`).

## Consequences

- The platform is modular: external agent orchestrators (Alexa+, desktop hosts) can use GozVision capabilities through standard MCP tools.
- Real-time video processing is latency-free and privacy-preserving.
- Clinician adoption friction is reduced through transparent SOAP verification.
- Patient outreach moves from static blast messages to conversational appointment negotiation.
