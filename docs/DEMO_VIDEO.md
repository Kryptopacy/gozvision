# GozVision — Official Demonstration Video & Walkthrough Script

> **Competition Track:** OpenCV AI Competition 2026 (Healthcare & Accessibility)  
> **Compiled Production Video:** [`gozvision_opencv_demo.mp4`](file:///d:/pacy_labs/gozvision/gozvision_opencv_demo.mp4) *(1080p @ 30 FPS, H.264 / AAC, Runtime: 1m 56s)*  
> **Generator Pipeline:** [`scripts/generate_opencv_demo_video.py`](file:///d:/pacy_labs/gozvision/scripts/generate_opencv_demo_video.py)  

---

## 🎬 Video Storyboard & Technical Production Breakdown

```
00:00 ──▶ 00:18  Segment 1: Clinical Problem Statement & OpenCV 5 Architecture
00:18 ──▶ 00:35  Segment 2: OpenCV 5 Telea Fast Marching Inpainting (Specular Glare)
00:35 ──▶ 00:55  Segment 3: DAVE Diagnosis-Adaptive Vision Enhancement (AMD vs Glaucoma)
00:55 ──▶ 01:14  Segment 4: 3D Spatial Depth & Pinhole Intrinsics Ray Backprojection (Drop Height in cm)
01:14 ──▶ 01:34  Segment 5: Epipolar Plane-plus-Parallax Homography (2D Shadow Veto)
01:34 ──▶ 01:56  Segment 6: Asynchronous Dual-Loop Decoupling (60 FPS HUD / 10 Hz Depth) & 109-Test Audit
```

---

### Segment 1: Clinical Problem Statement & OpenCV 5 Architecture (0:00 – 0:18)
- **Visual:** Clean 1080p OpenCV 5 brand card with architectural breakdown: Telea inpainting, DAVE scotoma masking, epipolar homography, pinhole ray backprojection, and asynchronous dual-loop decoupling.
- **Narration:** *"Over 2.2 billion people worldwide live with visual impairment, including macular degeneration, glaucoma, and cataracts. Existing mobility aids apply generic, uncalibrated filters that fail to address the patient's specific physiological scotoma. Welcome to GozVision: a clinical assistive vision copilot built entirely on OpenCV 5."*

---

### Segment 2: OpenCV 5 Telea Fast Marching Inpainting (0:18 – 0:35)
- **Visual:** Split screen. Left: Raw street camera feed blinded by intense specular glare from a windshield. Right: OpenCV 5 `cv::inpaint` with `INPAINT_TELEA` running Fast Marching reconstruction of the occluded sidewalk texture. Telemetry HUD indicates 4,512 px reconstructed hotspot area at 8.2 ms latency.
- **Narration:** *"For cataract and photophobia patients, bright sunlight and windshield reflections cause blinding specular glare. GozVision isolates glare hot spots and reconstructs occluded street textures using OpenCV 5 Telea Fast Marching inpainting, blending 70% reconstructed background with 30% attenuated natural luminance."*

---

### Segment 3: DAVE Diagnosis-Adaptive Vision Enhancement (0:35 – 0:55)
- **Visual:** Split screen comparing unprocessed clinical baseline against DAVE AMD Profile. The central macular scotoma region is preserved while the functioning peripheral annulus receives CLAHE contrast amplification. HUD telemetry displays Contrast Improvement Index ($CII = 1.52\times$) and Sighted-Region SSIM ($0.884$).
- **Narration:** *"Standard vision apps apply uniform contrast across the entire display. GozVision introduces DAVE: Diagnosis-Adaptive Vision Enhancement. Connected to the patient's FHIR clinical record, DAVE reads their ICD-10 diagnosis. For macular degeneration, it preserves the non-functioning central fovea and concentrates contrast amplification strictly on the functioning peripheral retina."*

---

### Segment 4: 3D Spatial Depth & Pinhole Intrinsics Drop Estimation (0:55 – 1:14)
- **Visual:** Pedestrian walking corridor approaching outdoor steps. Left: Camera feed with red bounding box highlighting the step-down hazard (`CAUTION: STEP DOWN 16.2 cm`). Right: OpenCV Inferno-colorized depth disparity field with Theil-Sen perspective baseline kink. Telemetry displays metric optical flow scale ($Z = 1.85\text{ m}$) and backprojection angle ($\gamma = 35.5^\circ$).
- **Narration:** *"To prevent catastrophic falls, GozVision analyzes the pedestrian walking corridor for 3D elevation breaks. Using calibrated pinhole camera intrinsics and Theil-Sen piecewise ground baseline fitting, the system backprojects rays to measure physical drop height in metric centimeters with calibrated tolerance bounds."*

---

### Segment 5: Epipolar Plane-plus-Parallax Ground Homography Veto (1:14 – 1:34)
- **Visual:** Comparison between a 2D cast tree shadow on pavement and a real 3D physical curb. RANSAC homography transfer error on the shadow is $1.18\text{ px}$ (below the $2.5\text{ px}$ planar threshold) and $\Delta E_{ab} = 0.82$, triggering green HUD indicator: `COPLANAR GROUND SHADOW VETOED — ALERT SUPPRESSED`. The real step exhibits $6.42\text{ px}$ parallax error, confirming the hazard.
- **Narration:** *"In assistive navigation, false alarm fatigue is dangerous. To distinguish real elevation breaks from flat shadows, GozVision fuses CIE-LAB photometric chrominance invariance with epipolar plane-plus-parallax homography testing. 2D shadows adhere to the floor homography and are vetoed, while real curbs trigger immediate guidance."*

---

### Segment 6: Asynchronous Dual-Loop Decoupling & Benchmarks (1:34 – 1:56)
- **Visual:** Full audit scorecard and performance dashboard. Displays 109/109 passing tests, Loop A 60 FPS HUD throughput ($P50 = 4.02\text{ ms}$), 89.3% video approach recall, and 100-patient in silico clinical trial results ($F=7.51, p < 0.001$).
- **Narration:** *"Under the hood, GozVision decouples frame processing into an asynchronous dual-loop architecture: Loop A delivers 60 frames per second smooth HUD rendering with sub-15 millisecond latency, while Loop B runs spatial depth inference in the background. Audited across 100 simulated clinical patients with 109 passing tests, that is GozVision."*

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
