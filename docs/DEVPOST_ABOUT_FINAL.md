# Devpost "About the project" — FINAL paste-ready markdown (2026-10-26)

Copy everything BELOW the line into the Devpost About field. It is written in
markdown; Devpost renders it. Do not paste from a rendered chat view.

---

## Inspiration

Over **2.2 billion people** globally live with vision impairment (WHO). Their needs span the whole day, indoors and outdoors: a person with cataracts is blinded by specular glare off wet pavement and kitchen counters; a person with macular degeneration cannot read a prescription bottle, an appliance panel, or a departure board; a person with advanced glaucoma facing a stairwell or a curb encounters the deadliest classical-CV failure there is.

To a 2D edge detector (Canny, Sobel, Laplacian), a 15 cm physical step-down is mathematically indistinguishable from a flat painted bicycle-lane stripe or a dark tree shadow — all three are high-gradient luminance contours. Alert on every edge and the user experiences alarm fatigue; suppress alerts and a stair becomes a fall. And generic algorithms apply uniform contrast enhancement to every user, ignoring the patient's individual ophthalmic profile: an AMD patient with a central scotoma needs peripheral contrast; a glaucoma patient with tunnel vision needs central clarity.

We built **GozVision** to answer one question per frame, correctly: **what does this specific patient's remaining vision need from this frame — and is this edge a real hazard or a coplanar pattern?** An autonomous, clinical-grade Agentic Vision Copilot built natively on OpenCV 5.0, measured on AWS Graviton, with an air-gapped local WebGPU option for clinical privacy.

---

## What it does

GozVision unites real-time edge computer vision with clinical EHR intelligence across two connected surfaces:

- **Goz Patient Copilot (B2C PWA / Mobile):**
  - **Full Aid Suite (synchronous display):** CIE-LAB adaptive CLAHE applied to luminance only (preserving chromaticity); Telea fast-marching inpainting (`cv2.inpaint`) to suppress specular glare from wet pavement and headlights for cataract patients; morphological reading-zone isolation that finds and highlights text blocks — medication labels, appliance panels, signage — for OCR and text-to-speech readout.
  - **DAVE — Diagnosis-Adaptive Vision Enhancement:** ingests the patient's FHIR ICD-10 codes (AMD `H35.31`, Glaucoma `H40.11`, Cataract `H26.9`, RP `H35.52`) and Humphrey Visual Field mean deviation to concentrate contrast gain in functioning retina instead of wasting it on a scotoma.
  - **Spatial-Depth Hazard Discriminator (the flagship):** monocular depth disparity via `cv2.dnn.readNetFromONNX` (MiDaS-small), StereoSGBM triangulation when a stereo baseline exists, a RANSAC ground-homography parallax veto for coplanar surfaces, and the core innovation: the **vertical depth-disparity gradient (∂D/∂y) test** across the walking corridor, gated by a 5-frame TemporalHazardCoherenceTracker. Output is a decision — `vertical_drop` (with estimated cm) vs `coplanar_clear` — for curbs, staircases, transit gaps, and indoor level changes alike, with real shadows suppressed as coplanar.
  - **Spatial Directional Acoustic Cues & Voice:** translates the 3D hazard vector into panned directional audio and spoken warnings ("Caution: step down to your left") for open-ear smart-audio frames.
  - **Agentic Closed Loop:** a vertical drop > 10 cm rewrites the agent's plan from passive monitoring to collision avoidance; post-hazard IMU stumble telemetry triggers an autonomous encrypted SOS dispatch to caregiver and clinic with GPS coordinates and a 10-second cancel window; prescription-label OCR is cross-checked against the patient's active EHR medications and halts administration on conflict, escalating to a clinician. *Verified live over MCP: a logged end-to-end session on our AWS endpoint shows a real stairs frame driving plan escalation → SOS dispatch → medication HALT (`docs/AGENTIC_MCP.md` §3, judge-runnable with `--local`).*

- **Goz Clinic Suite (B2B Practice Management Web Hub):**
  - **Ambient Clinical Scribe:** synthesizes doctor-patient dialogue into structured FHIR R4 and SOAP notes, with a runtime toggle between Cloud AI (HIPAA BAA zero-retention) and **Air-Gapped Local WebGPU inference — 100% on-device, zero network packets**.
  - **DAVE Clinical Configuration:** the practitioner's diagnosis and visual-field data dynamically configure the patient's mobile vision filters — the clinical profile literally becomes the computer-vision configuration.

---

## How we built it

1. **OpenCV 5 Vision Pipeline (`backend/gozvision_vision/cv_pipeline.py`):**
   - **Stage 1 (Optical Pre-processing):** BGR → LAB color space; CLAHE on the L channel only with condition-adaptive clip limits; glare masks attenuated via morphological dilation and Telea inpainting; lateral hazard clusters isolated independently via an active drop mask (`active_drop_mask`) so curbs entirely in the left or right third of the corridor still produce precise lateral centroids for directional panning.
   - **Stage 2 (DNN Depth Disparity Engine):** ONNX depth models via `cv2.dnn.readNetFromONNX` with `DNN_BACKEND_OPENCV`; StereoSGBM when stereo hardware exists.
   - **Stage 3 (Vertical Drop vs. Shadow Classifier):** the ∂D/∂y disparity-gradient test across the walking corridor, plus a RANSAC ground-homography veto and optical-flow scale calibration for monocular drop-height estimation.
   - **Temporal Hazard Coherence:** a 5-frame rolling window enforces geometric consistency — geometrically stable steps hold coherence while fluctuating ground shadows collapse and are suppressed as `coplanar_clear`.

2. **Cloud-Optimized OpenCV (COOL) on AWS Graviton (`backend/gozvision_vision/cool_pipeline.py`):**
   - Production runs the **linux/arm64 container on Graviton-backed Amazon ECS Fargate** (`CpuArchitecture: ARM64` in `infra/gozvision-stack.yaml`), with Universal Intrinsics SIMD vectorization; supports `CV_8U`, `CV_32F`, and `CV_16BF` datatypes.
   - Benchmarked head-to-head on **real AWS Spot instances** — Graviton2 (`t4g.small`) vs Intel x86 (`c7i-flex.large`) — identical OpenCV 5.0.0 build and DNN model on both sides (`scripts/run_graviton_benchmark.sh`).

3. **Agentic Vision & Spatial Audio (`backend/gozvision_agent/agentic_vision.py`):**
   - Multi-step perception-to-action workflows exposed as MCP tools over streamable HTTP: vision output rewrites the agent's goal state and drives `send_sos_alert`, `log_adherence_event`, and clinical SOAP-note drafting. Directional audio cues via the Web Audio API.

4. **Cloud Infrastructure:**
   - Amazon ECS Fargate (`gozvision-cluster`), AWS CloudFront TLS edge termination (`d7icpdzxenshi.cloudfront.net`), AWS Amplify hosting (`main.d1lr4zsb46he1m.amplifyapp.com`), Supabase PostgreSQL 16 with multi-tenant Row-Level Security.

---

## Challenges we ran into

1. **Distinguishing 2D texture from 3D geometry with commodity monocular hardware** was the core research problem. Single-frame classification of curbs vs shadows is genuinely hard — our honest single-frame number is a 0.66 F1 smoke test. The homography veto and 5-frame temporal coherence window were born from those failure cases: with temporal approach context, the same classifier reaches **71.4% recall / 100% precision / 0.0 false alarms per minute** on labelled approach sequences.
2. **Lateral curb boundary dropouts:** curbs entirely within the left or right third of the corridor initially produced zeroed bounding boxes. The active drop mask now isolates lateral hazard clusters independently, with regression-test coverage.
3. **Evaluating vision quality for scotoma patients:** full-frame SSIM penalizes adaptive enhancement because it averages pixel changes over blind retinal regions. We formulated Sighted-Region SSIM and a Contrast Improvement Index weighted to functioning retinal areas derived from visual-field tests — and it changes conclusions (documented in the eval report §8).
4. **Epistemic honesty in benchmarking:** our first benchmark draft attributed numbers to hardware they never ran on. We rewrote the benchmark to refuse cross-architecture claims that aren't measured — every number below now carries its environment label and telemetry, and we think the submission is stronger for it.

---

## Accomplishments that we're proud of

- **Measured AWS Graviton economics on real Spot instances** (identical benchmark, both sides — `backend/benchmark_results_graviton_t4g_small.json`, `benchmark_results_x86_c7i-flex_large.json`):
  - **Per-dollar result:** Graviton2 processes the identical workload **2.5–4.0x cheaper** per 1M frames (contrast $0.043 vs $0.169; glare $0.094 vs $0.368; reading ROI $0.0078 vs $0.0285; spatial-depth DNN $1.17 vs $2.87) — the decisive economics for always-on assistive computing.
  - **Per-core trade-off, stated honestly:** the newer-generation Intel instance is 1.29–2.08x faster in raw throughput; Graviton wins on cost.
  - **Dev-workstation measurements** (640x480, MiDaS-small DNN active): spatial depth 12.4 FPS, contrast 414 FPS, glare suppression 71 FPS, reading-zone isolation 919 FPS (`backend/benchmark_results.json`).
- **A reproducible evaluation harness on real imagery:** 69 real street/corridor frames (zero synthetic placeholders, Wikimedia-licensed, per-case SHA-256 recorded). We publish our own failure list — all 20 residual failures named by filename in `docs/EVALUATION_REPORT.md` §5.
- **DAVE, measured on sighted regions:** condition-specific contrast amplification across pathology cohorts is statistically significant in our in-silico trial (N=100, one-way ANOVA F(3,96) = 7.51, p < 0.001) — explicitly a simulation, not a clinical trial.
- **A true closed agentic loop, verified live — not narrated:** vision results change what the system does next, and we can prove it end to end. `scripts/run_agentic_mcp_session.py` runs a logged MCP session against our **live AWS endpoint**: a real stairs photo (SHA-256 recorded in the log) goes through the OpenCV 5 `spatial_depth` tool, detects an `elevation_barrier` (~21 cm drop), the client decision rule escalates the plan, the `agentic_vision_hazard_loop` executes a 4-step perception→reasoning→actuator→tool_call trace that dispatches a real SOS alert (`firestore_written: true`), and the medication guardrail HALTS a contraindicated drop and escalates to clinician review — all with `human_approval_required: true` at both escalation points. The raw session log with per-step latencies is preserved at `backend/evaluation/results/agentic_mcp_session_trace.json` (zero errors), the same command runs with `--local` for offline judging, and the telemetry call inside the same session attests `is_aws_graviton_arm: true` on the production task. Full trace: `docs/AGENTIC_MCP.md` §3.
- **Privacy sovereignty:** instant runtime toggle between cloud HIPAA BAA processing and 100% on-device WebGPU inference — zero biometric or clinical frames leave the room when required.

---

## What we learned

- **The ∂D/∂y disparity-gradient test is a cheap, effective coplanarity discriminator — but only with temporal context.** Single-frame numbers collapse; temporal approach kinematics are what separate a curb from its shadow.
- **Perception must drive actuation.** Patients with severe vision loss cannot interpret visual bounding boxes; the loop only closes when spatial perception becomes directional audio, haptics, and emergency actuation.
- **Full-frame metrics are the wrong metric for scotoma patients** — sighted-region weighting flips conclusions, and clinical context (ICD-10 + HVF) should configure the CV pipeline before frame one.
- **Honest evaluation survives judging better than a leaderboard.** Every number in this submission names the hardware it ran on.

---

## What's next for GozVision

- **Curated curb/stairs benchmark with surveyed cm ground truth** and on-glasses stereo-rig validation of SGBM metric depth.
- **Multi-center low-vision clinic partnerships and an IRB protocol** (drafted in repo docs) to measure real-world reduction in assistive-device abandonment and fall incidence.
- **Direct micro-firmware AR waveguide integration:** compiling the CLAHE and drop-disparity pipelines to ultra-lightweight smart-glass microcontrollers.
- **Graviton CI benchmark job** so the economics table stays measured, continuously.
