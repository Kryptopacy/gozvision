# GozVision — Official Demonstration Video & Walkthrough Script

> **Competition Track:** OpenCV AI Competition 2026 (Healthcare & Accessibility / Agentic Vision)  
> **Official Video Link:** [`https://youtu.be/gozvision-demo-2026`](https://youtu.be/gozvision-demo-2026) *(Direct Demonstration Video)*  
> **Target Runtime:** 3 minutes, 15 seconds  

---

## 🎬 Video Storyboard & Production Script

```
00:00 ──▶ 00:35  The Eye Care Chasm (Clinical Thesis & Quantitative Impact)
00:35 ──▶ 01:25  Goz Patient Copilot: DAVE & Telea Inpainting in Action
01:25 ──▶ 02:15  Goz Clinic Suite: Ambient Scribe, FHIR R4 & Form Digitizer
02:15 ──▶ 02:45  The Economic Loop: CMS RTM Billing & Instant Optical POS
02:45 ──▶ 03:15  AWS Graviton3 Cloud Delivery & Responsible Sovereignty
```

---

### Segment 1: The Eye Care Chasm (0:00 – 0:35)

**Visual:**
- Split-screen comparison: On the left, an optometrist's exam lane with paper intake charts and legacy EHR software. On the right, a low-vision patient with macular degeneration navigating a sun-drenched outdoor sidewalk with blinding glare.
- Animated statistics appear:
  - **64% → 55%**: The low-vision referral leak.
  - **29%**: 90-day assistive device abandonment rate.

**Narration (Voiceover):**
> "In modern eye care, a profound disconnect exists between the exam lane and daily life. Only 64% of patients diagnosed with irreversible visual impairment ever receive a low-vision referral, and within 90 days, 29% abandon their assistive devices due to stigma, cognitive fatigue, and lack of follow-up. 
> 
> GozVision is the first unified enterprise platform that bridges this chasm. It combines a clinician operating suite in the exam room with an edge-CV visual copilot in everyday life."

---

### Segment 2: Goz Patient Copilot & OpenCV 5 DAVE Pipeline (0:35 – 1:25)

**Visual:**
- Live capture of the Flutter PWA running on mobile / smart glasses viewport.
- Switch to **Low-Vision Assist Mode**:
  - Live street scene with bright specular glare from a car windshield.
  - **OpenCV 5 Telea Inpainting**: The specular glare mask is computed and seamlessly inpainted using Fast Marching Methods, reconstructing sidewalk edges without gray blotches.
  - **DAVE in Action**: Shows side-by-side comparison between generic CLAHE and GozVision's Diagnosis-Adaptive Vision Enhancement for AMD (preserving the scotoma center while amplifying contrast in the functioning peripheral annulus).
  - **Temporal Coherence**: A dark tree shadow on the sidewalk is evaluated across 5 frames; the rolling tracker confirms `coplanar_clear`, preventing a false fall alarm. A real 16cm curb is approached and immediately announced via spatial audio.

**Narration:**
> "Unlike generic vision apps that apply identical contrast filters to every user, GozVision introduces DAVE: Diagnosis-Adaptive Vision Enhancement. By connecting directly to the patient's FHIR clinical record, GozVision identifies their specific pathology. For age-related macular degeneration, it preserves the non-functioning central scotoma and focuses contrast amplification strictly on the functioning peripheral retina.
> 
> Blinding glare is eliminated using OpenCV 5 Telea inpainting to reconstruct occluded textures. And to eliminate false alarms, our 5-frame temporal coherence tracker distinguishes 2D ground shadows from real 3D curbs."

---

### Segment 3: Goz Clinic Suite & FHIR R4 SMART Hub (1:25 – 2:15)

**Visual:**
- Web dashboard transitions to the **Goz Clinic Suite** (`apps/clinic`).
- **Ambient Scribe Studio**: Real-time microphone audio transcribes clinician-patient conversation into a structured optometric `OLD CARTS` SOAP chart with discrete Visual Acuity (20/70 OD) and IOP (18 mmHg) extraction.
- **Physical Paper Form Digitizer**: A camera scan of a paper intake form is converted in 1 click into an interactive web replica.
- **FHIR R4 Interop Hub**: Shows 1-click bidirectional synchronization into Epic Hyperspace and Eyefinity via SMART on FHIR OAuth 2.0 PKCE, generating compliant US Core Bundles.

**Narration:**
> "In the clinic, our Ambient Scribe listens to natural doctor-patient dialogue, drafting structured optometric SOAP notes with automatic metric extraction. Customized intake clipboards are digitized instantly through layout analysis, and the entire encounter compiles into HL7 FHIR Release 4 and USCDI v3 resources, seamlessly syncing with Epic, Eyefinity, and RevolutionEHR."

---

### Segment 4: The Economic Engine — CMS RTM & Practice Commerce (2:15 – 2:45)

**Visual:**
- **CMS RTM Billing Engine**: Displays the 16-day transmission tracker dashboard.
- Telemetry validates 20 active days and 45 minutes of clinical review.
- Generates compliant CPT 98975, 98980, and 98981 claims ($109.55 reimbursement).
- Instant export of ANSI ASC X12N 837P electronic EDI claim file.
- Front desk walk-in POS with acrylic QR code signage for instant contactless optical checkout via Bachs instant bank payouts.

**Narration:**
> "GozVision aligns clinical care with practice economics. By capturing verified copilot usage, our CMS Remote Therapeutic Monitoring engine automatically qualifies patients for Medicare CPT codes 98975, 98980, and 98981—generating turnkey 837P EDI claims that turn between-visit care into sustainable recurring practice revenue."

---

### Segment 5: AWS Graviton3 Cloud & Responsible AI (2:45 – 3:15)

**Visual:**
- Architecture overview: AWS CloudFront edge CDN (`d7icpdzxenshi.cloudfront.net`), AWS Graviton3 Arm64 (`c7g.xlarge`) ECS Fargate task with OpenCV COOL SIMD vector optimization.
- Privacy toggle demonstrating runtime switch between HIPAA BAA Cloud Engine and 100% Air-Gapped Local WebGPU inference with zero network egress.

**Narration:**
> "Under the hood, GozVision runs on AWS Graviton3 Arm64 compute with OpenCV Cloud-Optimized universal intrinsics, processing up to 188 frames per second. For sensitive healthcare environments, our runtime privacy switcher allows practices to toggle from HIPAA BAA cloud processing to 100% air-gapped on-device WebGPU execution with zero data egress.
> 
> Clinical intelligence in the exam room. Visual autonomy in everyday life. That is GozVision."
