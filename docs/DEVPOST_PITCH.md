# Devpost Submission Copy — GozVision (OpenCV AI Competition 2026)

Paste-ready copy for each Devpost field. Every number below is measured and
reproducible from the repo; see docs/TECHNICAL_REPORT.md section 9 for the
exact commands.

---

## Project title

```
GozVision — OpenCV 5 Assistive Vision Copilot for Low Vision
```

## Elevator pitch (Devpost ~200-char line)

```
A 2D edge filter can't tell a 15 cm stair from a painted stripe. GozVision
can: OpenCV 5 depth disparity + temporal coherence separate real hazards from
flat patterns — indoors and outdoors — with contrast, glare and reading aids
tuned to each patient's diagnosis.
```

## About the project (full description)

**The problem.** 2.2 billion people live with vision impairment (WHO), and
their needs span the whole day, indoors and outdoors: a person with cataracts
is blinded by specular glare off wet pavement and kitchen counters; a person
with macular degeneration cannot read a prescription bottle, an appliance
panel, or a departure board; a person with advanced glaucoma navigating a
stairwell or a curb faces the deadliest classical-CV failure there is — a 2D
edge detector (Canny, Sobel) responds identically to a 15 cm elevation change
and to a flat painted line or a dark floor shadow. Alert on every edge and
the user experiences alarm fatigue; suppress alerts and a stair becomes a
fall. GozVision is a full-spectrum assistive vision copilot built around one
question per frame, answered correctly: **what does this specific patient's
remaining vision need from this frame — and is this edge a real hazard or a
coplanar pattern?**

**The full aid suite (Loop A, synchronous display):** CIE-LAB adaptive CLAHE
on luminance only; Telea fast-marching inpainting of specular glare
(`cv2.inpaint`); morphological reading-zone isolation that finds and
highlights text blocks for OCR — medication labels, appliances, signage,
documents — indoors and out; and DAVE, diagnosis-adaptive spatial masks
derived from the patient's FHIR ICD-10 codes so contrast gain concentrates in
functioning retina instead of being wasted on a scotoma.

**The spatial-depth flagship (Loop B, asynchronous geometry):** the deepest
CV innovation is the indoor/outdoor hazard discriminator — monocular depth
disparity via `cv2.dnn.readNetFromONNX` (MiDaS-small), StereoSGBM
triangulation when a stereo baseline exists, a RANSAC ground-homography
parallax veto for coplanar surfaces, optical-flow scale calibration, and the
core innovation: the **vertical depth-disparity gradient (∂D/∂y) test**
across the walking corridor, gated by a 5-frame `TemporalHazardCoherenceTracker`.
Output is a decision — `vertical_drop` (with estimated cm) vs
`coplanar_clear` — for staircases, curbs, transit gaps, and indoor level
changes alike.

**The honesty section (read this, judges).** On 69 real street/corridor frames
(0 synthetic, Wikimedia-licensed, per-case SHA-256 recorded), single-frame
classification is a **0.66 F1 smoke test — we say so in the report**. With
temporal approach context (5-frame coherence + homography veto), the same
classifier reaches **71.4% recall / 100% precision / 0.0 false alarms per
minute** on labelled approach sequences. All 20 residual failures are listed
by filename in `docs/EVALUATION_REPORT.md` §5. Estimated drop height in
monocular mode is a calibrated heuristic, not a surveyed metric — stated in
the report, not hidden.

**The agent.** Vision results change what the system does next
(`gozvision_agent/agentic_vision.py`, exposed as MCP tools over streamable
HTTP): vertical drop > 10 cm rewrites the agent's plan from passive monitoring
to collision avoidance (directional audio + haptic pulse); post-hazard IMU
stumble telemetry triggers autonomous encrypted SOS dispatch to caregiver and
clinic with a 10-second cancel window; prescription-label OCR is checked
against the patient's active EHR medications and **halts administration** on
conflict, escalating to a human clinician. A chatbot explaining a fixed vision
result this is not — every stage feeds the next.

**AWS / COOL.** Production runs the linux/arm64 container on Graviton-backed
Amazon ECS Fargate behind CloudFront (IaC: `infra/gozvision-stack.yaml`,
`CpuArchitecture: ARM64`). Our benchmark emits **only measured numbers**
(`backend/benchmark_cool_graviton.py`): dev-workstation, OpenCV 5.0.0,
640x480, DNN active — spatial depth 12.4 FPS, enhanced contrast 414 FPS,
glare suppression 71 FPS, reading-zone isolation 919 FPS. We then ran the
identical benchmark on real AWS Spot instances — Graviton2 (`t4g.small`) and
Intel (`c7i-flex.large`) — and measured: Intel is 1.29–2.08x faster per mode,
while **Graviton delivers the same workload 2.5–4.0x cheaper per million
frames** (spatial depth $1.17 vs $2.87 per 1M frames; reading $0.0078 vs
$0.0285). Reproduce both runs yourself: `scripts/run_graviton_benchmark.sh` +
`compare_benchmarks.py`; full telemetry in
`backend/benchmark_results_graviton_t4g_small.json` and
`backend/benchmark_results_x86_c7i-flex_large.json`.

**Reproducibility.** Pinned deps (`opencv-python-headless>=5.0.0,<5.1`,
`numpy>=2.0,<3`), fresh-venv verified: 27/27 tests pass
(`pytest test_cv_pipeline.py test_cool_pipeline.py test_agentic_vision.py`).
Full commands in `docs/TECHNICAL_REPORT.md` §9.

## Live endpoints

| What | URL |
|---|---|
| API (CloudFront → ECS Fargate) | https://d7icpdzxenshi.cloudfront.net |
| Health check | https://d7icpdzxenshi.cloudfront.net/health |
| Interactive API docs | https://d7icpdzxenshi.cloudfront.net/docs |
| Patient & clinic web apps | https://main.d1lr4zsb46he1m.amplifyapp.com |

## Challenges

Distinguishing 2D texture from 3D geometry with commodity monocular hardware
was the core research problem; the homography veto and temporal coherence
window were born from its failure cases. The second challenge was epistemic:
our first benchmark draft attributed numbers to hardware they never ran on. We
rewrote the benchmark to refuse cross-architecture claims that aren't
measured, and we think the submission is stronger for it.

## What we learned

- The ∂D/∂y disparity-gradient test is a cheap, effective coplanarity
  discriminator — but only with temporal context; single-frame numbers collapse.
- Full-frame SSIM is the wrong metric for scotoma patients; sighted-region
  weighting changes conclusions (documented in the eval report, §8).
- Honest evaluation survives judging better than a leaderboard.

## What's next

Curated curb/stairs benchmark with surveyed cm ground truth; on-glasses
stereo rig validation of SGBM metric depth; clinical IRB protocol (drafted in
repo docs); Graviton CI benchmark job.

## Built with

```
opencv 5.0.0, python 3.14, numpy, cv2.dnn (ONNX MiDaS-small), StereoSGBM,
calcOpticalFlowFarneback, calcOpticalFlowPyrLK, cv2.inpaint (Telea), CLAHE,
AWS ECS Fargate (ARM64/Graviton), CloudFront, AWS Amplify, CloudFormation,
FastAPI, FastMCP (streamable HTTP), Flutter (PWA), Supabase PostgreSQL (RLS)
```

---

### Devpost "special award" opt-in note (if the form asks)

- **Best Use of COOL:** Graviton-backed ARM64 Fargate production target +
  measured-only benchmark methodology + one-command instance benchmark script
  for judges (`scripts/run_graviton_benchmark.sh`).
- **Agentic Vision Award:** vision output rewrites the agent plan, triggers
  tool calls (SOS, EHR guardrail, scribe draft), and escalates to humans with
  failure handling (10 s cancel window, physician sign-off).
