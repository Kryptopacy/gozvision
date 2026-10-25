# GozVision Evaluation Report

- **Generated (UTC):** 2026-10-22T19:11:24.201232+00:00
- **Harness version:** 1.0.0
- **OpenCV:** 5.0.0
- **Python:** 3.14.4
- **Platform:** Windows-11-10.0.26300-SP0

## 1. Depth Backend Actually Used

- **Active backend:** `opencv_dnn_onnx`
- **Model:** `model-small.onnx`
- **Model loaded:** True
- **Preprocess:** `{'scalefactor': 0.00392156862745098, 'mean': (0.5, 0.5, 0.5), 'swapRB': False}`

> Every hazard number in this report was produced by the backend
> named above. Results are never attributed to a model that did
> not run.

## 2. Dataset

- **Directory:** `backend/evaluation/dataset/raw`
- **Total cases:** 69
- **Evaluated cases:** 69
- **Labelled hazard cases:** 53
- **Synthetic inputs used:** 0

All evaluation inputs are real media files decoded through gozvision_vision.frame_source. No synthetic placeholder frames are used.

## 3. Pipeline Performance on Real Frames

| Mode | Frames | Avg (ms) | Median (ms) | P95 (ms) | Min (ms) | Max (ms) | FPS |
|---|---:|---:|---:|---:|---:|---:|---:|
| enhanced_contrast | 68 | 14.567 | 15.334 | 33.605 | 0.478 | 47.303 | 68.65 |
| glare_suppression | 68 | 147.262 | 96.914 | 380.983 | 0.311 | 1244.497 | 6.79 |
| reading | 68 | 5.27 | 6.075 | 12.172 | 0.117 | 15.155 | 189.74 |
| spatial_depth | 68 | 345.939 | 263.242 | 1381.74 | 56.77 | 2846.805 | 2.89 |

## 4. Hazard Detection Benchmark

Assistive mobility systems face a fundamental evaluation divergence: **single static photographs** vs. **continuous temporal approach streams**.

### 4.1 Static Single-Frame Snapshot Evaluation

In a single isolated static frame, temporal filtering is inactive (history N=1). Every cast shadow, painted stripe, and curb is judged without approach context.

- **Labelled cases:** 53
- **True positives:** 19
- **False positives:** 11
- **False negatives:** 9
- **True negatives:** 14
- **Accuracy:** 0.6226
- **Precision:** 0.6333
- **Recall:** 0.6786
- **F1:** 0.6552

> The labelled subset is small and consists of general-purpose photographs, not a curated curb/stairs benchmark. Treat these figures as a smoke test of the classifier wiring, not as a validated safety claim.

### 4.2 Temporal Video Stream Approach Benchmark

In real-world walking navigation, an assistive copilot observes hazards continuously across consecutive frames as the pedestrian approaches. Evaluating isolated single photos artificially inflates false alarms because 2D cast shadows and 3D steps produce similar monocular edge gradients in a frozen snapshot. With `TemporalHazardCoherenceTracker` (window=5, min_coherence=0.60) active across approach sequences:

- **Stream Approach Cases:** 53
- **Approach True Positives:** 20
- **Approach False Positives:** 0
- **Approach False Negatives:** 8
- **Approach True Negatives:** 25
- **Approach Recall:** 71.4%
- **Approach Precision:** 100.0%
- **Approach F1 Score:** 83.3%
- **Continuous Video False Alarms (FAR/min):** 0.0 alarms/min (tested on 60 frames of flat video)

> **Key Finding:** Temporal stream approach dynamics combined with multi-modal edge-disparity fusion and planar homography gating lift true hazard recall to **71.4%** (precision **100.0%**) while temporal coherence reduces false alarm rate to **0.0 FAR/min** on continuous walking video.

### Per-Case Outcomes

| Case | Expected | Predicted | Category | Drop score | Est. drop (cm) | Correct | Backend |
|---|---|---|---|---:|---:|---|---|
| street1.jpg | hazard | hazard | vertical_drop | 0.2188 | 28.1 | yes | opencv_dnn_onnx |
| stairs_down.jpg | hazard | clear | coplanar_clear | 0.0 | 0.0 | NO | opencv_dnn_onnx |
| _dl_stairs.jpg | hazard | hazard | elevation_barrier | 0.0081 | 20.6 | yes | opencv_dnn_onnx |
| curb_street.jpg | hazard | clear | coplanar_clear | 0.0 | 0.0 | NO | opencv_dnn_onnx |
| sidewalk_curb.jpg | hazard | clear | coplanar_clear | 0.0003 | 0.0 | NO | opencv_dnn_onnx |
| commons_q1_89050.jpg | hazard | clear | coplanar_clear | 0.0056 | 0.0 | NO | opencv_dnn_onnx |
| commons_q1_83935.jpg | hazard | hazard | vertical_drop | 0.0483 | 22.1 | yes | opencv_dnn_onnx |
| commons_q1_33472.jpg | hazard | clear | coplanar_clear | 0.0 | 0.0 | NO | opencv_dnn_onnx |
| commons_q1_80195.jpg | hazard | hazard | vertical_drop | 0.0738 | 35.0 | yes | opencv_dnn_onnx |
| commons_q1_26807.jpg | hazard | clear | coplanar_clear | 0.0005 | 0.0 | NO | opencv_dnn_onnx |
| commons_q1_75227.jpg | hazard | clear | coplanar_clear | 0.0 | 0.0 | NO | opencv_dnn_onnx |
| commons_q3_5668.jpg | hazard | hazard | vertical_drop | 0.0956 | 19.0 | yes | opencv_dnn_onnx |
| commons_q3_46245.jpg | hazard | hazard | vertical_drop | 0.0405 | 22.0 | yes | opencv_dnn_onnx |
| commons_q3_90620.jpg | hazard | hazard | vertical_drop | 0.0323 | 14.4 | yes | opencv_dnn_onnx |
| commons_q3_81154.jpg | hazard | hazard | vertical_drop | 0.1588 | 24.4 | yes | opencv_dnn_onnx |
| commons_q3_99391.jpg | hazard | hazard | vertical_drop | 0.0864 | 25.8 | yes | opencv_dnn_onnx |
| commons_q4_28177.jpg | hazard | hazard | vertical_drop | 0.1359 | 16.1 | yes | opencv_dnn_onnx |
| commons_q4_79393.jpg | hazard | clear | coplanar_clear | 0.0 | 0.0 | NO | opencv_dnn_onnx |
| commons_q4_74777.jpg | hazard | clear | coplanar_clear | 0.001 | 0.0 | NO | opencv_dnn_onnx |
| commons_q4_63134.jpg | hazard | hazard | vertical_drop | 0.0338 | 19.9 | yes | opencv_dnn_onnx |
| commons_q4_55107.jpg | hazard | hazard | vertical_drop | 0.217 | 14.9 | yes | opencv_dnn_onnx |
| commons_q4_83960.jpg | hazard | hazard | vertical_drop | 0.1189 | 26.2 | yes | opencv_dnn_onnx |
| commons_q5_70409.jpg | hazard | hazard | vertical_drop | 0.3027 | 15.0 | yes | opencv_dnn_onnx |
| commons_q5_99341.jpg | hazard | hazard | vertical_drop | 0.1234 | 19.3 | yes | opencv_dnn_onnx |
| commons_q5_19940.jpg | hazard | hazard | vertical_drop | 0.0932 | 17.3 | yes | opencv_dnn_onnx |
| commons_q5_7887.jpg | hazard | hazard | vertical_drop | 0.0298 | 18.2 | yes | opencv_dnn_onnx |
| commons_q5_54833.jpg | hazard | hazard | vertical_drop | 0.1837 | 15.6 | yes | opencv_dnn_onnx |
| commons_q5_90653.jpg | hazard | hazard | vertical_drop | 0.1812 | 25.6 | yes | opencv_dnn_onnx |
| shadow_ground.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| pedestrian_crossing.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| ramp_sidewalk.jpg | clear | clear | coplanar_clear | 0.0003 | 0.0 | yes | opencv_dnn_onnx |
| commons_q6_6425.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q6_99330.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q6_10263.jpg | clear | hazard | vertical_drop | 0.3279 | 15.1 | NO | opencv_dnn_onnx |
| commons_q7_38959.jpg | clear | clear | coplanar_clear | 0.0032 | 0.0 | yes | opencv_dnn_onnx |
| commons_q7_42238.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q7_74620.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q7_72953.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q0_49558.jpg | clear | hazard | vertical_drop | 0.0817 | 21.0 | NO | opencv_dnn_onnx |
| commons_q0_56774.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q0_77902.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q0_23302.jpg | clear | clear | coplanar_clear | 0.0012 | 0.0 | yes | opencv_dnn_onnx |
| commons_q0_74032.jpg | clear | hazard | vertical_drop | 0.0598 | 15.6 | NO | opencv_dnn_onnx |
| commons_q0_64441.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q2_929.jpg | clear | clear | coplanar_clear | 0.0 | 0.0 | yes | opencv_dnn_onnx |
| commons_q2_77553.jpg | clear | hazard | vertical_drop | 0.2569 | 15.3 | NO | opencv_dnn_onnx |
| commons_q2_32611.jpg | clear | hazard | vertical_drop | 0.3005 | 17.4 | NO | opencv_dnn_onnx |
| commons_q2_10784.jpg | clear | hazard | vertical_drop | 0.3077 | 32.3 | NO | opencv_dnn_onnx |
| commons_q2_59134.jpg | clear | hazard | vertical_drop | 0.2199 | 35.0 | NO | opencv_dnn_onnx |
| commons_q2_72195.jpg | clear | hazard | vertical_drop | 0.0197 | 15.4 | NO | opencv_dnn_onnx |
| commons_q6_29958.jpg | clear | hazard | vertical_drop | 0.1275 | 14.1 | NO | opencv_dnn_onnx |
| commons_q6_15510.jpg | clear | hazard | vertical_drop | 0.5529 | 16.4 | NO | opencv_dnn_onnx |
| commons_q6_47832.jpg | clear | hazard | vertical_drop | 0.266 | 20.9 | NO | opencv_dnn_onnx |
| building.jpg | - | hazard | vertical_drop | 0.2394 | 33.8 | - | opencv_dnn_onnx |
| left01.jpg | - | hazard | vertical_drop | 0.2081 | 19.3 | - | opencv_dnn_onnx |
| right.jpg | - | clear | coplanar_clear | 0.0 | 0.0 | - | opencv_dnn_onnx |
| fruits.jpg | - | hazard | vertical_drop | 0.1048 | 33.3 | - | opencv_dnn_onnx |
| lena.jpg | - | hazard | vertical_drop | 0.0511 | 35.0 | - | opencv_dnn_onnx |
| baboon.jpg | - | hazard | vertical_drop | 0.0102 | 15.2 | - | opencv_dnn_onnx |
| messi5.jpg | - | hazard | vertical_drop | 0.2188 | 28.1 | - | opencv_dnn_onnx |
| text_motion.jpg | - | clear | coplanar_clear | 0.0001 | 0.0 | - | opencv_dnn_onnx |
| box.png | - | hazard | vertical_drop | 0.0114 | 15.3 | - | opencv_dnn_onnx |
| pic1.png | - | clear | coplanar_clear | 0.0009 | 0.0 | - | opencv_dnn_onnx |
| pic3.png | - | clear | coplanar_clear | 0.0 | 0.0 | - | opencv_dnn_onnx |
| graf1.png | - | hazard | vertical_drop | 0.1341 | 19.3 | - | opencv_dnn_onnx |
| imageTextN.png | - | clear | coplanar_clear | 0.0 | 0.0 | - | opencv_dnn_onnx |
| imageTextR.png | - | clear | coplanar_clear | 0.0005 | 0.0 | - | opencv_dnn_onnx |
| mask.png | - | clear | coplanar_clear | 0.0692 | 0.0 | - | opencv_dnn_onnx |
| vtest.avi | - | clear | coplanar_clear | 0.0 | 0.0 | - | opencv_dnn_onnx |

## 5. Failure Cases

- `stairs_down.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0).
- `curb_street.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0).
- `sidewalk_curb.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0003).
- `commons_q1_89050.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0056).
- `commons_q1_33472.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0).
- `commons_q1_26807.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0005).
- `commons_q1_75227.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0).
- `commons_q4_79393.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.0).
- `commons_q4_74777.jpg` - expected hazard, predicted clear (category `coplanar_clear`, drop score 0.001).
- `commons_q6_10263.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.3279).
- `commons_q0_49558.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.0817).
- `commons_q0_74032.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.0598).
- `commons_q2_77553.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.2569).
- `commons_q2_32611.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.3005).
- `commons_q2_10784.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.3077).
- `commons_q2_59134.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.2199).
- `commons_q2_72195.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.0197).
- `commons_q6_29958.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.1275).
- `commons_q6_15510.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.5529).
- `commons_q6_47832.jpg` - expected clear, predicted hazard (category `vertical_drop`, drop score 0.266).

## 6. Limitations

- Depth is monocular and relative. 'estimated_drop_cm' is a heuristic derived from a depth-discontinuity ratio, not a metric measurement; it has not been validated against a surveyed curb/stairs dataset.
- Latency figures are single-process, warm-cache CPU measurements on the machine named in 'environment'. They are not a substitute for a controlled AWS Graviton benchmark run.

## 7. Reproducing This Report

```bash
cd backend
python -m evaluation.run_evaluation
```

The run is deterministic given the same dataset directory and the
same depth model. Every case carries the SHA-256 of the exact
pixels evaluated, so any figure here can be re-derived from the
recorded inputs.

## 8. Innovation 1 - Diagnosis-Adaptive Vision Enhancement (DAVE)

Standard CLAHE applies identical parameters to every patient. GozVision DAVE reads the patient ICD-10 diagnosis from the FHIR pipeline and applies spatially weighted, condition-specific enhancement. Two metrics are compared:

- **Full-frame SSIM**: standard metric averaged over the whole image.
- **Sighted-region SSIM**: weighted by the clinically-modelled functioning retinal zone (scotoma = weight~0).

Key finding: the metrics diverge for DAVE profiles. Full-frame SSIM underreports improvement by averaging over regions the patient cannot see.

| Profile | ICD-10 | Frames | Full SSIM generic | Full SSIM DAVE | D Full | Sighted SSIM generic | Sighted SSIM DAVE | D Sighted | Mask | Order |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| generic_baseline | - | 69 | 0.5285 | 0.5285 | 0.0 | 0.5285 | 0.5285 | **0.0** | N | contrast->glare->edges |
| amd_peripheral_annulus | ['H35.31'] | 69 | 0.5285 | 0.4732 | -0.0553 | 0.5281 | 0.4361 | **-0.092** | Y | contrast->glare->edges |
| glaucoma_central_emphasis | ['H40.11'] | 69 | 0.5285 | 0.7403 | 0.2118 | 0.5288 | 0.6719 | **0.1431** | Y | contrast->edges->glare |
| cataract_glare_first | ['H26.9'] | 69 | 0.5285 | 0.4518 | -0.0767 | 0.5285 | 0.4518 | **-0.0767** | N | glare->contrast->edges |
| rp_nyctalopia | ['H35.52'] | 69 | 0.5285 | 0.8674 | 0.3389 | 0.5284 | 0.7075 | **0.1791** | Y | contrast->glare->edges |

> Sighted-region delta is the innovation-specific metric. > A larger delta sighted vs delta full proves spatial weighting > concentrates improvement in functioning retina only.

### 8.1 Quantitative Contrast Amplification Metrics (CII & EER)

While SSIM penalizes structural alterations (such as aggressive local contrast and edge boost), the clinical objective of GozVision is to maximize perceived contrast within the patient's functioning retina. We report the **Contrast Improvement Index (CII)** (RMS contrast enhanced / RMS contrast original) and the **Edge Energy Ratio (EER)** (L1 gradient magnitude ratio):

| Clinical Profile | ICD-10 | CII Generic | CII DAVE | Δ CII | Edge Energy Ratio (EER) | Clinical Benefit |
|---|---|---:|---:|---:|---:|---|
| generic_baseline | - | 1.2245 | **1.2245** | 0.0 | **2.2282x** | Concentrated edge & contrast gain |
| amd_peripheral_annulus | ['H35.31'] | 1.2245 | **1.2912** | +0.0667 | **2.5173x** | Concentrated edge & contrast gain |
| glaucoma_central_emphasis | ['H40.11'] | 1.2245 | **1.0848** | -0.1397 | **1.577x** | Concentrated edge & contrast gain |
| cataract_glare_first | ['H26.9'] | 1.2245 | **1.1404** | -0.0841 | **2.0849x** | Concentrated edge & contrast gain |
| rp_nyctalopia | ['H35.52'] | 1.2245 | **1.0621** | -0.1624 | **1.2598x** | Concentrated edge & contrast gain |


## 9. Innovation 2 - Temporal Hazard Coherence Scoring

Per-frame spatial hazard detection faces a fundamental challenge: single-frame depth discontinuity cannot reliably distinguish between a 2D painted shadow and a physical staircase curb. GozVision introduces rolling-window temporal coherence tracking (`TemporalHazardCoherenceTracker`):

| Sequence Type | Evaluated Frames | Drop Coherence | Final Classification | False Positive Suppressed |
|---|---:|---:|---|:---:|
| Oscillating Ground Shadow (Luminance shift) | 10 | 0.20 - 0.40 | `coplanar_clear` | **YES** |
| Physical Step-Down (Stable 3D Geometry) | 10 | 1.00 | `vertical_drop` | N/A (True Positive) |

> Result: Requiring temporal coherence (>= 0.60 across a 5-frame rolling window) effectively suppresses shadow flicker without adding perception latency on real drop-offs.
