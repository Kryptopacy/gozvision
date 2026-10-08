# GozVision — Hackathon Master Submission & Pitch Guide

> **Ecosystem:** GozVision (Rebirth of GozAI)  
> **Tagline:** The Dual-Sided Clinical & Real-Time Computer Vision Copilot for Low-Vision Accessibility.  
> **Target Tracks:** 
> - **AWS Global AI & Developer Challenge** (Cloud Infrastructure, ECS Fargate, CloudFront, Amplify, MCP)
> - **OpenCV AI Competition 2026** (Healthcare & Accessibility / Agentic Computer Vision)
> - **Google Gemini Multi-Turn & Multimodal Agent Competitions** (Real-time Scribe & Spatial Vision)

---

## 1. Executive Summary

Over **2.2 billion people** globally live with vision impairment (WHO). For conditions like Age-Related Macular Degeneration (AMD), Diabetic Retinopathy, and Cataracts, patients face a severe double-sided burden:
1. **In the Real World:** Loss of contrast sensitivity causes lethal trip-and-fall hazards on curbs and stairs; blinding glare prevents street crossing; fine text on prescription labels is unreadable.
2. **In the Eye Clinic:** Doctors spend up to 40% of their consultation time typing EHR notes instead of examining eyes, leading to physician burnout, missing follow-ups, and fragmented patient care.

**GozVision** bridges this divide with an end-to-end, dual-sided ecosystem:
- **Patient Visual Copilot (Flutter PWA / Mobile):** Combines an on-device **OpenCV 5** edge-enhancement computer vision pipeline with **Gemini Multimodal Vision**, offering hands-free hazard salience, specular glare suppression, text magnification, and one-tap emergency SOS triage.
- **Clinical Practice Portal (Flutter Web):** Ambient clinical AI scribe that transcribes doctor-patient consultations directly into structured FHIR/SOAP EHR notes, manages clinic branches and practitioner rosters, and automates patient recall messaging.
- **Enterprise Cloud Backbone (AWS + Supabase):** Deployed live on **Amazon ECS Fargate** with global **AWS CloudFront HTTPS CDN** SSL termination, continuous builds via **AWS CodeBuild**, **Amplify Hosting**, and **Supabase PostgreSQL** with Row-Level Security (RLS).

---

## 2. Live Deployment Endpoints & Credentials

All GozVision services are currently live, operational, and publicly verifiable by judges:

| Component | Technology | Live URL |
| :--- | :--- | :--- |
| **Global HTTPS API Gateway** | AWS CloudFront (SSL CDN) | `https://d7icpdzxenshi.cloudfront.net` |
| **Backend Container Runtime** | Amazon ECS Fargate | `http://16.171.40.255:8080` (Direct Ingress) |
| **Interactive API Documentation**| FastAPI / Swagger UI | `https://d7icpdzxenshi.cloudfront.net/docs` |
| **Live Health Check** | Amazon ECS Task Health | `https://d7icpdzxenshi.cloudfront.net/health` |
| **Frontend Web Apps** | AWS Amplify Hosting | `https://main.d1lr4zsb46he1m.amplifyapp.com` |
| **Database & Tenancy** | Supabase Postgres (AWS eu-west-1) | `aws-0-eu-west-1.pooler.supabase.com:6543` |
| **Source Code Repository** | GitHub | `https://github.com/Kryptopacy/gozvision` |

### Verified Demo Accounts
*Password for all pre-seeded accounts:* `gozvision-demo`

- **Medical Doctor / Clinic Manager:** `demo-doctor@gozvision.demo`
- **Optometric Staff / Reception:** `demo-staff@gozvision.demo`
- **Low-Vision Patient:** `demo-patient@gozvision.demo`

---

## 3. The 3-Minute Winning Video Pitch & Demo Storyboard

```
[0:00 - 0:25] THE HOOK & THE CRISIS
Visual: Split screen: An elderly woman with macular degeneration hesitating before low-contrast stairs,
        contrasted with an exhausted eye doctor furiously typing at a keyboard during an eye exam.
Voiceover:
"2.2 billion people live with vision impairment. In the physical world, losing contrast sensitivity turns 
a simple sidewalk curb or flight of stairs into a life-threatening fall. In the eye clinic, doctors spend 
nearly half their day typing clinical notes rather than examining patients. 
Meet GozVision: the first dual-sided computer vision and ambient clinical intelligence platform engineered 
to protect low-vision patients on the street, and liberate eye doctors in the clinic."

[0:25 - 1:15] PATIENT COPILOT: OPENCV 5 ACCESSIBILITY IN ACTION
Visual: Show the live GozVision Patient PWA running on mobile / desktop. Toggle the real-time OpenCV 5 filters.
        Show the high-resolution split-screen triptych (docs/assets/gozvision_opencv_triptych.png).
Voiceover:
"For low-vision patients, GozVision runs a real-time OpenCV 5 visual copilot:
First, our Adaptive Contrast Engine uses CLAHE in LAB color space and morphological edge salience to sharply 
delineate curb steps and stair hazards that AMD patients cannot normally distinguish.
Second, our Specular Highlight Suppressor attenuates blinding window and headlights glare, restoring 
navigational vision for cataract sufferers.
Third, our Morphological Reading Pipeline instantly identifies medication labels and dosage instructions, 
routing high-confidence text boxes directly into spoken audio."

[1:15 - 1:55] CLINICAL SUITE: AMBIENT SCRIBE & PRACTICE MANAGEMENT
Visual: Doctor starts consultation. Live ambient audio waveform activates. Doctor speaks: 
        'Eleanor presents with worsening central scotoma in OS. Visual acuity 20/80. Plan: continue Timolol.'
        In 2 seconds, GozVision generates a structured, ICD-10 coded SOAP clinical note and logs it to Supabase.
Voiceover:
"Inside the clinic, GozVision acts as an ambient ophthalmic scribe powered by Gemini 2.5. 
Doctors simply speak with their patients. GozVision captures the dialogue and synthesizes structured SOAP 
notes, visual acuity metrics, and prescription refills directly into the clinical EHR.
Clinic managers can oversee multi-branch facilities, license rosters, and optometric technician lanes 
with enterprise role-based security."

[1:55 - 2:35] ENTERPRISE ARCHITECTURE: AWS & MODEL CONTEXT PROTOCOL
Visual: Pan across the AWS Cloud Architecture diagram and live terminal showing AWS CloudFront and ECS Fargate.
Voiceover:
"Under the hood, GozVision is built for sub-second, enterprise-grade reliability:
Our containerized Python backend runs on Amazon ECS Fargate, compiled in the cloud via AWS CodeBuild, and pushed 
to Amazon ECR. 
Global SSL acceleration is terminated worldwide through AWS CloudFront, while our web PWAs are hosted on 
AWS Amplify.
Our agentic core uses the Model Context Protocol (MCP) to seamlessly bind Gemini reasoning with live Supabase 
PostgreSQL vector search and automated emergency SOS dispatch."

[2:35 - 3:00] THE IMPACT & CALL TO ACTION
Visual: Patient smiling while reading medication with audio readout; doctor reviewing a completed patient chart.
        Final title slide: GozVision — Restoring Sight, Empowering Care.
Voiceover:
"GozVision isn't just an AI concept. It is live on AWS today, clinically grounded, and ready to empower 
millions of low-vision individuals to navigate their world with independence. 
Thank you."
```

---

## 4. Deep-Dive Judging Alignment Matrix

### Track 1: AWS Global Developer Challenge (Cloud & Agentic Infrastructure)
- **Zero-Downtime Serverless Containers:** Built and deployed on **Amazon ECS Fargate** (`gozvision-cluster`), eliminating manual OS patching while auto-scaling to zero-idle workloads.
- **Cloud-Native CI/CD:** Complete automated pipeline using **AWS CodeBuild** (`gozvision-container-builder`) compiling multi-package Python wheel artifacts inside Amazon Linux containers and pushing directly to **Amazon ECR** (`202504327910.dkr.ecr.eu-north-1.amazonaws.com/gozvision-backend`).
- **Global Edge Performance & Security:** Multi-region edge acceleration via **AWS CloudFront** (`d7icpdzxenshi.cloudfront.net`) providing:
  - Global TLS 1.3/1.2 SSL termination (eliminating mixed-content issues for browser PWAs).
  - CachingDisabled policy for sub-second dynamic streaming API routes.
  - Header forwarding preservation (`Managed-AllViewerExceptHostHeader`).
- **Serverless Frontend Delivery:** Deployed on **AWS Amplify Hosting** with custom Single-Page Application (SPA) routing rewrites for clinical sub-paths (`/clinic/*`) and patient sub-paths (`/patient/*`).
- **Agent Toolkit for AWS Compliance:** Configured with AWS MCP profiles, native IAM Least Privilege execution roles (`gozvision-ecs-execution-role`), and CloudWatch logging groups (`/ecs/gozvision-backend`).

### Track 2: OpenCV AI Competition 2026 (Healthcare & Accessibility)
- **Clinical Problem-Specific Computer Vision:** Rather than generic object detection, GozVision targets specific ophthalmologic pathologies:
  - *Macular Degeneration (AMD):* Contrast Limited Adaptive Histogram Equalization (CLAHE) with Sobel/Canny edge salience overlay to recover lost depth perception on curb edges and stairs.
  - *Cataracts & Photophobia:* Specular bloom thresholding with morphological dilation to dim blinding reflective glare while preserving background context.
  - *Reading Rehabilitation:* Morphological gradient filtering with Otsu binarization and rectangular structural kernels to isolate dense text lines on medicine bottles for low-vision patients.
- **Validated Visual Evidence:** Complete side-by-side comparison graphics generated and committed in `docs/assets/` (`gozvision_opencv_triptych.png`).

### Track 3: Google Gemini Multi-Turn & Multimodal Hackathons
- **Real-Time Multimodal Audio & Vision:** Interfaces with Gemini Flash models for spatial understanding, reading assistance, and emergency visual triage.
- **Ambient Clinical Scribe:** Real-time conversational dialogue parsing into standardized clinical SOAP schemas (Subjective, Objective, Assessment, Plan).
- **Model Context Protocol (MCP):** Connects the Gemini agent to external tools:
  - `query_clinic_knowledge_base`: Semantic RAG over ophthalmic clinical guidelines.
  - `trigger_emergency_sos`: Automated dispatch for disoriented or injured low-vision users.
  - `record_clinical_encounter`: Direct writes to PostgreSQL EHR records.

---

## 5. Architectural Blueprint

```
+---------------------------------------------------------------------------------+
|                                 CLIENT CLIENTS                                  |
|   +----------------------------------+    +----------------------------------+  |
|   |   GozVision Patient Companion    |    |      GozVision Clinic Suite      |  |
|   |  (Flutter PWA / OpenCV 5 Camera) |    |   (Ambient Scribe / Roster Mgmt) |  |
|   +----------------------------------+    +----------------------------------+  |
|                     ^                                       ^                   |
|                     | Hosted on AWS Amplify                 |                   |
|                     v                                       v                   |
|          https://main.d1lr4zsb46he1m.amplifyapp.com                             |
+---------------------------------------------------------------------------------+
                                       |
                                       | HTTPS (Port 443)
                                       v
+---------------------------------------------------------------------------------+
|                       AWS CLOUDFRONT GLOBAL CDN & SSL                           |
|                  https://d7icpdzxenshi.cloudfront.net                           |
|       - TLS 1.3 Termination  - Managed Cache Policy (Dynamic API Ingress)       |
+---------------------------------------------------------------------------------+
                                       |
                                       | HTTP Ingress (Port 8080)
                                       v
+---------------------------------------------------------------------------------+
|                      AMAZON ECS FARGATE (gozvision-cluster)                     |
|                   Task: 3f6a07168454418fb6bcc0363b506504                        |
|                                                                                 |
|   +-------------------------------------------------------------------------+   |
|   | FastAPI ADK API Server (uvicorn @ 0.0.0.0:8080)                         |   |
|   |                                                                         |   |
|   |  +---------------------+   +---------------------+   +---------------+  |   |
|   |  | OpenCV 5 Vision Core|   | Gemini Agent Engine |   | GozVision MCP |  |   |
|   |  | (CLAHE/Edge/Glare)  |   | (Scribe / Spatial)  |   | (Tools Server)|  |   |
|   |  +---------------------+   +---------------------+   +---------------+  |   |
|   +-------------------------------------------------------------------------+   |
|                                      |                                          |
|         CloudWatch Logs: /ecs/gozvision-backend                                 |
+---------------------------------------------------------------------------------+
                                       |
                                       | Postgres Connection Pooler (Port 6543)
                                       v
+---------------------------------------------------------------------------------+
|                      SUPABASE POSTGRESQL (AWS EU-WEST-1)                        |
|   - Multi-tenant Clinics, Practitioners, Staff, Patients                        |
|   - Row-Level Security (RLS) & Developer Role Hierarchy                         |
|   - Clinical Encounters, SOAP Notes, & Emergency SOS Triage Logs                |
+---------------------------------------------------------------------------------+
```

---

## 6. How to Verify & Run Locally

```bash
# 1. Clone repository
git clone https://github.com/Kryptopacy/gozvision.git
cd gozvision

# 2. Run backend test suite
cd backend
python -m unittest discover tests

# 3. Test the OpenCV low-vision asset generation pipeline
python -m gozvision_vision.generate_demo_assets

# 4. Check live CloudFront backend health
curl https://d7icpdzxenshi.cloudfront.net/health
```
