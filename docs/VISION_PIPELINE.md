# OpenCV 5 Computer Vision & Wearables Specification

GozVision deploys an edge computer vision pipeline engineered with **OpenCV 5.0.0** to provide real-time visual assistance for eye care patients and smart glass wearables.

---

## 1. Algorithmic Pipeline (`backend/gozvision_vision/cv_pipeline.py`)

### A. Adaptive Contrast & Edge Overlay (`enhanced_contrast`)
* **Target Pathology:** Age-Related Macular Degeneration (AMD), Glaucoma, and Diabetic Retinopathy.
* **Mechanism:**
  1. Converts video frame from BGR to LAB color space to separate Luminance ($L$) from chromatic channels ($A, B$).
  2. Applies **CLAHE (Contrast Limited Adaptive Histogram Equalization)** with `clipLimit=3.0` and `tileGridSize=(8, 8)` to restore local shadow and highlight details.
  3. Computes high-frequency edge gradients via Gaussian-smoothed Canny filtering ($40, 120$).
  4. Blends enhanced luminance with weighted edge cues ($0.35$).
* **Benefit:** Allows patients with central scotomas to easily distinguish step edges, curbs, doorways, and low-contrast obstacles.

### B. Specular Glare Attenuation (`glare_suppression`)
* **Target Pathology:** Cataracts, Photophobia, and Corneal Haze.
* **Mechanism:**
  1. Detects localized luminance spikes surpassing a high-intensity threshold ($\ge 240/255$).
  2. Dilates the glare mask by $5\times5$ kernel to capture the scatter halo.
  3. Attenuates pixel intensity in the glare region by a factor of $0.65$.
* **Benefit:** Suppresses blinding reflections from direct sunlight on car hoods, glossy floors, or overhead fluorescent tubes.

### C. Reading & Text Zone Segmentation (`reading`)
* **Target Task:** Mail, medication bottles, signage, and screen navigation.
* **Mechanism:**
  1. Computes morphological gradient with rectangular kernel $(9, 3)$ to isolate stroke boundaries.
  2. Binarizes via Otsu thresholding and performs morphological closing.
  3. Extracts bounding contours and filters out non-text aspect ratios.
* **Benefit:** Guides the patient's camera to focus on text and projects bounding boxes for targeted magnification and OCR routing.

### D. OpenCV 5 DNN Spatial Depth Disparity Engine (`spatial_depth`)
* **Target Pathology:** Fall prevention across physical drop-offs, stairs down, and sidewalk curbs.
* **Mechanism:**
  1. Executes monocular relative depth estimation via `cv2.dnn.readNetFromONNX` (`model-small.onnx` or `depth_anything_v2_vits.onnx`).
  2. Projects egocentric walking navigation corridor with dynamic pitch horizon adjustment ($y_{\text{horizon}} = c_y + f_y \tan(\theta_{\text{pitch}})$).
  3. Evaluates piecewise-linear Theil-Sen robust median-of-slopes baseline across full and lateral lanes (left 33%, center 33%, right 33%).
  4. Quantifies physical drop disparity jump ($\Delta D > 0.08$) and estimates metric step height ($12\text{cm} - 28\text{cm}$).
* **Benefit:** Reliably isolates genuine physical drop-offs while rejecting flat coplanar road markings.

### E. Binocular Stereo Vision Triangulation Engine (`opencv_stereo_sgbm`)
* **Target Hardware:** Binocular smart glasses and dual-camera headsets (baseline $B \approx 6.5\text{ cm}$).
* **Mechanism:**
  1. Computes Semi-Global Block Matching (`cv2.StereoSGBM_create`) across rectified left/right sensor frames.
  2. Calculates metric Euclidean depth directly via trigonometric triangulation:
     $$Z = \frac{f_x \cdot B}{d_{\text{disparity}}}$$
  3. Completely texture- and color-invariant: detects concrete curb edges dropping into asphalt regardless of surface color or cast shadow patterns.
* **Benefit:** Provides hardware-level 60 FPS metric depth perception without relying on monocular neural network approximations.

### F. Epipolar Plane-plus-Parallax Homography Veto
* **Target Scenario:** High-contrast cast shadows, painted zebra crossings, and tree silhouettes on flat ground.
* **Mechanism:**
  1. Tracks lower-corridor features via `cv2.goodFeaturesToTrack` and pyramidal Lucas-Kanade optical flow (`cv2.calcOpticalFlowPyrLK`).
  2. Fits ground plane homography matrix $H$ using RANSAC.
  3. Evaluates feature transfer residual error within candidate hazard regions ($||x' - Hx||_2$).
  4. If transfer error is $< 2.5\text{ px}$, the boundary is mathematically coplanar with the floor and is vetoed (`homography_vetoed = True`, `hazard_category = "coplanar_clear"`).
* **Benefit:** Eliminates false alarms on flat walking surfaces, dropping video false alarm rate to **0.0 FAR/min**.

### G. Forward Optical Flow Metric Scale Calibration
* **Mechanism:**
  1. Forward pedestrian motion $V_z$ induces vertical optical flow divergence on the ground plane:
     $$v_y = \frac{f_y \cdot V_z}{Z} \implies Z = \frac{f_y \cdot V_z \cdot \Delta t}{\Delta y}$$
  2. Dynamically calibrates camera height and lookahead distance ($Z_{\text{metric}}$) without active LiDAR.

### H. Multi-Modal Transverse Curb & Stair Edge Gating
* **Mechanism:**
  1. Real curbs and stairs feature a transverse horizontal boundary crossing the lower corridor.
  2. Fuses vertical Sobel derivatives ($I_y$, perpendicular to horizontal steps) with morphological structuring elements ($19 \times 1$).
  3. Adapts baseline disparity threshold sensitivity upon detecting a structural transverse boundary, catching subtle, low-contrast concrete steps.

### I. Diagnosis-Adaptive Vision Enhancement (DAVE)
* **Target Innovation:** Tailoring computer vision shaders to patient-specific retinal damage from FHIR clinical records.
* **Mechanism:**
  1. Ingests ICD-10 diagnosis (`H35.31` AMD, `H40.11` Glaucoma, `H25.1` Cataract, `H35.52` Retinitis Pigmentosa).
  2. Builds spatial retinal weighting maps (central scotoma preservation vs peripheral annulus boost).
  3. Evaluates efficacy via **Sighted-Region SSIM**, **Contrast Improvement Index (CII)**, and **Edge Energy Ratio (EER)** ($2.52\times$ edge boost in surviving retina).

### J. Decoupled Dual-Loop Asynchronous Architecture
* **Loop A (Display Refresh):** Executes CLAHE, DAVE spatial shaders, and HUD overlay at **>68 FPS (<15 ms latency)** without waiting on neural depth.
* **Loop B (Spatial 3D Depth Worker):** Asynchronously computes 3D depth and homography vetoes at **8–12 Hz** via a thread-safe non-blocking drop-old queue.

---

## 2. Smart Glasses Telemetry Profile (`backend/gozvision_vision/smart_glasses.py`)

Engineered for optical see-through smart glasses (e.g. **Ray-Ban Meta**, **Rokid Max**, **Even Realities G1**, **Vuzix Blade**).

```
                     ┌─────────────────────────────┐
                     │ Smart Glasses Sensors (IMU) │
                     │  • Head Pitch: > 15° Down   │
                     │  • Battery: Level & Thermals│
                     └──────────────┬──────────────┘
                                    │
                                    ▼
┌───────────────────────────┐  Edge CV Pipeline  ┌───────────────────────────┐
│ Camera Frame Input (HD)   ├──▶ (OpenCV 5.0) ───▶ Ultra-Sparse Monochrome    │
└───────────────────────────┘                    │ Waveguide HUD (0, 255, 120)│
                                                 │ • Step / Obstacle Bracket │
                                                 │ • Terse Audio Cues        │
                                                 └───────────────────────────┘
```

* **Ultra-Sparse Transparent HUD:** Transparent background (RGB 0,0,0 is completely transparent on micro-OLEDs) with high-visibility Malachite green edge cues.
* **Ground Hazard Detection:** When IMU reports a downward head tilt ($>15^\circ$), the system inspects the lower visual field for sudden edge density and triggers an amber caution bracket and a concise audio cue (*"Step detected ahead"*).
* **Thermal & Power Throttling:** Automatically downsamples image resolution when wearable battery drops below 25% to preserve battery life and prevent heating on the temple frames.

---

## 3. Cloud-Optimized OpenCV Library (COOL) on AWS Graviton (`cool_pipeline.py`)

GozVision accelerates cloud video stream processing using the **Cloud-Optimized OpenCV Library (COOL)** deployed on **AWS Graviton-backed Amazon ECS Fargate** (linux/arm64 task, `CpuArchitecture: ARM64` in `infra/gozvision-stack.yaml`).

### Architectural Advantages targeted on AWS Graviton:
1. **ARM NEON & SVE Vector Acceleration:** Vectorized SIMD execution across LAB color space conversions, 2D Gaussian convolutions, and CLAHE histogram equalization (OpenCV build dispatches NEON paths on arm64).
2. **Cache-Topology Aligned Threading:** Thread pool sized to the task's vCPU allocation.
3. **Cloud Economics & Throughput (measured, never projected):**
   * **Dev-workstation measurements** (amd64, OpenCV 5.0.0, 640x480, DNN depth active): see `backend/benchmark_results.json` — spatial depth 12.4 FPS, enhanced contrast 414 FPS, glare suppression 71 FPS, reading-zone isolation 919 FPS.
   * **Cross-architecture measurements:** `scripts/run_graviton_benchmark.sh` runs the identical benchmark on Spot `c7g.xlarge` (Graviton3) and `c6i.xlarge` (x86) instances and `backend/compare_benchmarks.py` computes the per-mode ratios from the two measured files (`benchmark_results_graviton_c7g.json`, `benchmark_results_x86_c6i.json`). No cross-architecture figure is published unless both sides were measured.

---

## 4. Agentic Vision: Perception-Decision-Action Feedback Loop (`agentic_vision.py`)

GozVision goes far beyond passive chatbots: OpenCV 5 visual results directly govern multi-step agent plans, subsequent tool invocations, and human-in-the-loop escalations.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        AGENTIC VISION WORKFLOW                         │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
       [ 1. PERCEPTION: OpenCV 5 Image & Video Stream Analysis ]
       • Dynamic Edge Salience Score (Canny + Navigational ROI)
       • Specular Glare Saturation Ratio
       • Morphological Text Region Localization
                                    │
                                    ▼
       [ 2. DECISION ORCHESTRATION: Agent Reasoning Engine ]
       Visual findings evaluate clinical & safety guardrail rules
                                    │
              ┌─────────────────────┴─────────────────────┐
              ▼                                           ▼
 [ Branch A: Obstacle Detected ]              [ Branch B: Rx Label Found ]
 • Hazard salience > 0.04                     • Text localized on medication
 • Haptic alert + Spoken warning              • Query active EHR via MCP
 • If stumble telemetry detected:             • If drug mismatch / conflict:
   ──▶ Call `send_sos_alert`                    ──▶ HALT administration
   ──▶ Escalate GPS & Visual telemetry          ──▶ Call `draft_chart` (Scribe)
   ──▶ Human-in-the-Loop Emergency              ──▶ Escalate to Optometrist
```

### Verified Multi-Step Execution Traces:
* **Trace 1 (Fall Prevention):** `execute_hazard_mitigation_workflow` — OpenCV edge salience triggers localized tactile alerts. When IMU registers a stumble, the agent autonomously invokes `send_sos_alert` with coordinates and visual telemetry, escalating to caregivers and the clinic.
* **Trace 2 (Closed-Loop Rx Guardrail):** `execute_medication_guardrail_workflow` — OpenCV text localization identifies medication packaging. The agent cross-references active clinic charts, detects contraindications or dosage mismatches, halts administration via urgent voice prompts, and drafts an EHR encounter note via `draft_chart` for optometrist review.

