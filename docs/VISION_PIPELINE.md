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
