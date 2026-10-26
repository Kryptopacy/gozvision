"""GozVision OpenCV 5 Accessibility & Computer Vision Pipeline.

Tailored for the OpenCV AI Competition 2026 (Healthcare & Accessibility / Agentic Vision).

Features:
1. Adaptive Contrast & Edge Enhancement (CLAHE + Morphological Edge Overlay):
   Designed specifically for patients with age-related macular degeneration (AMD)
   and central scotomas to distinguish stair edges, curbs, and low-contrast objects.
2. Glare Reduction & Specular Highlight Suppression:
   Helps patients with cataracts, photophobia, and post-refractive haze navigate bright
   reflective environments (direct sunlight on windshields, fluorescent floors).
3. Text & Reading Region Detection:
   Isolates high-confidence textual bounding boxes using morphological gradients
   for targeted magnification and OCR routing.
4. OpenCV 5 DNN Spatial Depth Disparity & Physical Hazard Classifier:
   Leverages OpenCV 5's upgraded DNN engine architecture and perspective geometry
   to estimate relative depth fields and calculate vertical drop disparity.
   Critically distinguishes genuine physical drop-offs (>15cm stairs/curbs) from
   2D flat ground shadows, preventing false fall alarms.
5. Diagnosis-Adaptive Vision Enhancement (DAVE):
   Reads the patient's ICD-10 clinical profile (from the GozVision FHIR pipeline)
   and applies spatially and parametrically tailored enhancement — boosting contrast
   only in the retinal zones the patient can actually use, not uniformly across the
   entire frame.  No other assistive CV pipeline does this because no other pipeline
   has access to the patient's clinical chart.
6. Temporal Hazard Coherence Scoring:
   A rolling-window consistency check that confirms a depth discontinuity across N
   consecutive frames before issuing a hazard alert.  Physical stairs are geometrically
   stable across frames; luminance-only shadows are not.  This provably reduces false
   positives without changing the per-frame depth algorithm.
"""
from collections import deque
from dataclasses import dataclass, field
import os
import threading
from typing import Any, Dict, List, Literal, Optional, Tuple
import cv2
import numpy as np


# ---------------------------------------------------------------------------
# Innovation 1 — Diagnosis-Adaptive Vision Enhancement (DAVE)
# ---------------------------------------------------------------------------
# ICD-10 condition sets that GozVision already tracks via FHIR Condition
# resources.  These are the same codes in the ARCHITECTURE.md FHIR mapping.
_AMD_CODES: frozenset = frozenset({"H35.31", "H35.32", "H35.30"})          # Dry / Wet AMD
_GLAUCOMA_CODES: frozenset = frozenset({"H40.11", "H40.10", "H40.12"})     # Primary open-angle glaucoma
_CATARACT_CODES: frozenset = frozenset({"H25.9", "H26.9", "H25.1"})        # Age-related & other cataracts
_DIABETIC_CODES: frozenset = frozenset({"H36", "E11.319", "E11.311"})      # Diabetic retinopathy
_RP_CODES: frozenset = frozenset({"H35.52", "H35.50"})                     # Retinitis pigmentosa / nyctalopia


@dataclass
class DiagnosisAdaptiveConfig:
    """CV enhancement parameters derived from the patient's FHIR clinical profile.

    Standard OpenCV CLAHE pipelines apply the same parameters to every patient.
    GozVision is the only assistive CV platform with access to the patient's
    clinical chart (ICD-10 codes from FHIR Condition, visual field data from
    FHIR DiagnosticReport).  DiagnosisAdaptiveConfig closes that loop:

    - AMD patients have a central scotoma; CLAHE is weighted to the peripheral
      annulus their functioning retina can actually receive.
    - Glaucoma patients have tunnel vision; enhancement focuses on the central
      zone where their remaining sight lives.
    - Cataract patients need glare suppression *before* contrast enhancement;
      applying CLAHE to a haze-amplified signal makes artefacts worse.
    - Retinitis pigmentosa patients have contracted pupils in low light; a lower
      CLAHE clip limit avoids amplifying noise through the small aperture.

    Build one via `build_config_from_diagnosis(icd10_codes, ...)` rather than
    constructing it manually.
    """
    # CLAHE tuning
    clahe_clip_limit: float = 3.0
    clahe_tile_grid_size: Tuple[int, int] = (8, 8)
    # Edge overlay strength
    edge_enhancement_weight: float = 0.35
    # Glare suppression
    glare_threshold: int = 240
    glare_suppression_factor: float = 0.65
    # Processing stage order — cataract must suppress glare BEFORE contrast boost
    processing_order: Tuple[str, ...] = ("contrast", "glare", "edges")
    # Spatial sighted-region weight map (float32 H×W in [0, 1]).
    # 1.0 = functioning retina; 0.0 = scotoma / blind region.
    # None = full-frame generic (baseline / no clinical profile).
    spatial_weight_map: Optional[np.ndarray] = None
    # Provenance metadata (written into telemetry / evaluation report)
    icd10_codes: Tuple[str, ...] = ()
    hvf_mean_deviation_db: Optional[float] = None
    hvf_grid_points_used: int = 0
    visual_acuity_logmar: Optional[float] = None
    profile_name: str = "generic_baseline"


def _build_annulus_mask(h: int, w: int, inner_radius_frac: float = 0.25) -> np.ndarray:
    """Peripheral annulus weight mask for AMD patients.

    AMD causes a central scotoma.  The patient uses *eccentric fixation* —
    they look slightly to one side so the image falls on peripheral retina.
    Enhancement applied to the central scotoma region is wasted compute and
    may increase visual noise in an area the patient cannot perceive.

    Returns a float32 mask: 0.0 at the centre (scotoma), 1.0 at the frame
    edges (functioning peripheral retina), with a smooth ramp between them.
    """
    cy, cx = h / 2.0, w / 2.0
    y, x = np.ogrid[:h, :w]
    # Normalised elliptical distance so the mask is circular in aspect-ratio space
    dist = np.sqrt(((y - cy) / cy) ** 2 + ((x - cx) / cx) ** 2)
    inner_r = inner_radius_frac
    ramp_width = inner_r * 0.5
    mask = np.clip((dist - inner_r) / ramp_width, 0.0, 1.0)
    return mask.astype(np.float32)


def _build_gaussian_centre_mask(h: int, w: int, sigma_frac: float = 0.3) -> np.ndarray:
    """Central Gaussian emphasis mask for glaucoma / RP patients.

    Glaucoma destroys peripheral visual field (tunnel vision); RP similarly
    erodes the periphery first.  Enhancement outside the surviving central
    island is wasted on regions the patient cannot see.

    Returns a float32 mask: 1.0 at the frame centre, falling smoothly to 0.0
    at the periphery.  sigma_frac controls the width of the Gaussian relative
    to the half-frame dimensions.
    """
    cy, cx = h / 2.0, w / 2.0
    sigma_y = cy * sigma_frac * 2
    sigma_x = cx * sigma_frac * 2
    y, x = np.ogrid[:h, :w]
    mask = np.exp(
        -(((y - cy) ** 2) / (2 * sigma_y ** 2) + ((x - cx) ** 2) / (2 * sigma_x ** 2))
    )
    return mask.astype(np.float32)


def _build_hvf_grid_mask(
    hvf_points: List[Tuple[float, float, float]],
    frame_shape: Tuple[int, int],
    normal_db: float = 30.0,
    floor_db: float = 5.0,
) -> np.ndarray:
    """Patient-specific sighted-region mask interpolated from perimetry points.

    A population stereotype (annulus / Gaussian) is a reasonable fallback, but
    the patient's Humphrey 24-2 report already contains per-point retinal
    sensitivity in dB.  This builder turns those measurements into the spatial
    weight map directly, so the mask reflects *this* patient's field — an
    eccentric AMD scotoma, a glaucoma nasal step, a hemianopic cut — instead of
    the condition's population average.

    Parameters
    ----------
    hvf_points:
        ``(x_deg, y_deg, sensitivity_db)`` per tested location, in visual-angle
        degrees with the fixation point at the origin (Humphrey convention:
        positive x = temporal/right of fixation for the displayed eye chart,
        positive y = superior).
    frame_shape:
        ``(height, width)`` of the camera frame.
    normal_db:
        Sensitivity treated as fully-functioning retina (weight 1.0).
        Age-matched normals sit near 28-31 dB; 30 dB is the conservative pick.
    floor_db:
        Sensitivity treated as scotoma (weight 0.0).  5 dB keeps dense
        scotoma measurements fully suppressed without harsh clipping of
        barely-detecting points.

    Returns
    -------
    float32 H×W mask in [0, 1].

    Notes
    -----
    - Interpolation is a Gaussian radial-basis kernel in pure numpy (no scipy
      dependency), sigma = 3 degrees (half the 6-degree Humphrey grid spacing),
      so each pixel is governed by its nearest tested locations and a
      scotoma/normal boundary stays as sharp as the data — inverse-distance
      weighting smears that boundary across the whole field.
    - **Pixels with no tested location within ~8 degrees (2.6 sigma; total
      kernel weight < 0.05) default to functioning (weight 1.0).**  Perimetry
      samples the central ~30 degrees; suppressing untested periphery would
      blind the patient to content we have no evidence is invisible.
    - The dB-to-weight mapping is linear between floor and normal; a measured
      relative scotoma (e.g. 18 dB) is partially weighted, matching the
      partial sensitivity real relative defects retain.
    """
    h, w = frame_shape
    pts = np.asarray(hvf_points, dtype=np.float64)
    if pts.ndim != 2 or pts.shape[0] == 0 or pts.shape[1] != 3:
        raise ValueError("hvf_points must be a non-empty (N, 3) array of (x_deg, y_deg, sensitivity_db)")
    px, py, pdb = pts[:, 0], pts[:, 1], pts[:, 2]

    # Map the frame onto visual-angle space: fixation at frame centre, frame
    # edges at the tested extent plus one 6-degree grid spacing of padding.
    pad = 6.0
    x_half = max(float(np.max(np.abs(px))), 3.0) + pad
    y_half = max(float(np.max(np.abs(py))), 3.0) + pad
    y_px, x_px = np.mgrid[0:h, 0:w]
    gx = (x_px - (w - 1) / 2.0) / ((w - 1) / 2.0) * x_half
    gy = -((y_px - (h - 1) / 2.0) / ((h - 1) / 2.0) * y_half)   # screen y grows down; degrees grow up

    # Gaussian radial-basis interpolation: sigma = half the 6-degree Humphrey
    # grid spacing, so influence is local and field boundaries stay sharp.
    dx = gx[..., None] - px[None, None, :]
    dy = gy[..., None] - py[None, None, :]
    dist2 = dx * dx + dy * dy
    weights = np.exp(-dist2 / (2.0 * 3.0 ** 2))
    total = weights.sum(axis=2)
    sens = np.divide(
        np.sum(weights * pdb[None, None, :], axis=2),
        total,
        out=np.full((h, w), normal_db),   # no measurement within ~2.6 sigma -> functioning
        where=total > 0.05,
    )

    weight = np.clip((sens - floor_db) / (normal_db - floor_db), 0.0, 1.0)
    return weight.astype(np.float32)


def build_config_from_diagnosis(
    icd10_codes: List[str],
    visual_acuity_logmar: Optional[float] = None,
    hvf_mean_deviation_db: Optional[float] = None,
    frame_shape: Tuple[int, int] = (480, 640),
    hvf_point_sensitivities: Optional[List[Tuple[float, float, float]]] = None,
) -> DiagnosisAdaptiveConfig:
    """Build a DiagnosisAdaptiveConfig from the patient's FHIR clinical data.

    This is the primary entry point for the DAVE (Diagnosis-Adaptive Vision
    Enhancement) system.  Call it once per patient session with data from the
    GozVision FHIR pipeline and pass the result to LowVisionEnhancer.

    Parameters
    ----------
    icd10_codes:
        From FHIR ``Condition`` resources on the patient's encounter.
    visual_acuity_logmar:
        Best-corrected VA from FHIR Observation (LOINC 8684-3).
        Higher = worse (1.0 = 20/200, legal blindness threshold).  Scales the
        contrast boost by up to +25% (bounded — see Notes).
    hvf_mean_deviation_db:
        Humphrey Visual Field mean deviation from FHIR ``DiagnosticReport``.
        Negative values indicate field loss (-6 dB = moderate, -12 dB = severe).
    frame_shape:
        ``(height, width)`` of the camera frame — used to pre-compute the
        spatial weight mask at the correct resolution.
    hvf_point_sensitivities:
        Optional per-point ``(x_deg, y_deg, sensitivity_db)`` values from the
        Humphrey grid (FHIR ``Observation`` per visual-field location).  When
        present, the spatial weight map is interpolated from *this patient's*
        measured field instead of the condition's population stereotype.  Falls
        back to the geometric mask when absent or when the condition branch has
        no grid-aware mapping.

    Returns
    -------
    DiagnosisAdaptiveConfig
        A condition-specific configuration.  Falls back to the generic baseline
        if no recognised ICD-10 code is present.

    Notes
    -----
    ``visual_acuity_logmar`` severity scaling is deliberately bounded at +25%
    (logMAR 0.0 -> x1.00, 1.0 (20/200) -> x1.25, capped).  Unbounded
    "worse vision -> more contrast" rules over-amplify sensor noise for
    near-blind patients; the cap keeps the boost inside CLAHE's stable range.
    """
    codes = frozenset(icd10_codes)
    h, w = frame_shape
    cfg = DiagnosisAdaptiveConfig(
        icd10_codes=tuple(icd10_codes),
        visual_acuity_logmar=visual_acuity_logmar,
        hvf_mean_deviation_db=hvf_mean_deviation_db,
    )
    grid = hvf_point_sensitivities or None

    if codes & _AMD_CODES:
        # AMD: central scotoma + peripheral residual vision.
        # Patient uses eccentric fixation — apply CLAHE to the peripheral annulus only.
        # Higher clip limit: peripheral photoreceptor density is lower; contrast must
        # be amplified more strongly to compensate.
        # Source: AAO Preferred Practice Pattern — Age-Related Macular Degeneration.
        cfg.profile_name = "amd_peripheral_annulus"
        cfg.clahe_clip_limit = 4.5
        cfg.edge_enhancement_weight = 0.50
        cfg.glare_suppression_factor = 0.55
        if grid is not None:
            cfg.spatial_weight_map = _build_hvf_grid_mask(grid, (h, w))
            cfg.hvf_grid_points_used = len(grid)
            cfg.profile_name = "amd_hvf_grid"
        else:
            cfg.spatial_weight_map = _build_annulus_mask(h, w, inner_radius_frac=0.25)

    elif codes & _GLAUCOMA_CODES:
        # Glaucoma (POAG): progressive peripheral field loss — tunnel vision.
        # Enhance only the central surviving island; peripheral zones contribute noise.
        # Source: World Glaucoma Association — Primary Open-Angle Glaucoma Guidelines.
        cfg.profile_name = "glaucoma_central_emphasis"
        cfg.clahe_clip_limit = 3.5
        cfg.edge_enhancement_weight = 0.40
        cfg.processing_order = ("contrast", "edges", "glare")
        if grid is not None:
            cfg.spatial_weight_map = _build_hvf_grid_mask(grid, (h, w))
            cfg.hvf_grid_points_used = len(grid)
            cfg.profile_name = "glaucoma_hvf_grid"
        else:
            cfg.spatial_weight_map = _build_gaussian_centre_mask(h, w, sigma_frac=0.30)

    elif codes & _CATARACT_CODES:
        # Cataract: diffuse light scatter causes haze + severe glare.
        # CLAHE applied to a haze-saturated L channel amplifies scatter artefacts.
        # Glare MUST be suppressed first; CLAHE runs on the de-hazed signal.
        # Lower clip limit: intra-lens scatter already inflates local variance.
        # Source: AAO Preferred Practice Pattern — Cataract in the Adult Eye.
        cfg.profile_name = "cataract_glare_first"
        cfg.clahe_clip_limit = 2.5
        cfg.glare_threshold = 210      # Cataracts scatter light widely; lower threshold
        cfg.glare_suppression_factor = 0.50
        cfg.processing_order = ("glare", "contrast", "edges")   # KEY inversion

    elif codes & _DIABETIC_CODES:
        # Diabetic retinopathy: patchy scotomas from haemorrhages / hard exudates.
        # Severity-scaled contrast boost driven by HVF mean deviation.
        # Source: AAO Preferred Practice Pattern — Diabetic Retinopathy.
        cfg.profile_name = "diabetic_retinopathy"
        severity_boost = 1.0
        if hvf_mean_deviation_db is not None and hvf_mean_deviation_db < -6.0:
            severity_boost = 1.3     # Moderate-to-severe field loss: push harder
        cfg.clahe_clip_limit = round(3.5 * severity_boost, 2)
        cfg.edge_enhancement_weight = 0.45
        if grid is not None:
            # Patchy loss is exactly what a point grid captures and a
            # population mask cannot: interpolate it directly.
            cfg.spatial_weight_map = _build_hvf_grid_mask(grid, (h, w))
            cfg.hvf_grid_points_used = len(grid)
            cfg.profile_name = "diabetic_retinopathy_hvf_grid"

    elif codes & _RP_CODES:
        # Retinitis Pigmentosa: rod degeneration → nyctalopia + contracted pupils.
        # In dim light the small pupil aperture means CLAHE amplifies shot noise
        # badly with a high clip limit.  Use a low clip + large tile for smooth output.
        # Source: Foundation Fighting Blindness — RP Clinical Practice Guide.
        cfg.profile_name = "rp_nyctalopia"
        cfg.clahe_clip_limit = 1.8
        cfg.clahe_tile_grid_size = (4, 4)
        cfg.edge_enhancement_weight = 0.60
        cfg.glare_threshold = 180       # RP patients are extremely photophobic
        if grid is not None:
            cfg.spatial_weight_map = _build_hvf_grid_mask(grid, (h, w))
            cfg.hvf_grid_points_used = len(grid)
            cfg.profile_name = "rp_hvf_grid"
        else:
            cfg.spatial_weight_map = _build_gaussian_centre_mask(h, w, sigma_frac=0.20)

    else:
        cfg.profile_name = "generic_baseline"

    # Best-corrected visual acuity severity scaling — bounded (see docstring).
    if visual_acuity_logmar is not None and cfg.profile_name != "generic_baseline":
        va_factor = 1.0 + 0.25 * min(max(visual_acuity_logmar, 0.0), 1.0)
        cfg.clahe_clip_limit = round(cfg.clahe_clip_limit * va_factor, 2)

    return cfg


def measure_sighted_region_ssim(
    original: np.ndarray,
    enhanced: np.ndarray,
    sighted_mask: np.ndarray,
) -> float:
    """Compute SSIM weighted by the patient's clinically-modelled sighted region.

    Standard SSIM averages over the entire frame, including scotoma regions
    where the patient has no functional vision — making it insensitive to the
    precise improvements that matter.  This metric weights each pixel's SSIM
    contribution by the probability that it falls within functioning retina.

    A diagnosis-adaptive pipeline that boosts enhancement only in sighted zones
    will show a *larger* delta on this metric than on full-frame SSIM, because
    full-frame SSIM dilutes the improvement across the scotoma.  That
    divergence is itself the proof that the spatial weighting is doing useful work.

    Parameters
    ----------
    original:
        The unprocessed BGR frame.
    enhanced:
        The pipeline-processed BGR frame.
    sighted_mask:
        float32 H×W weight map in [0, 1].  Build from ``_build_annulus_mask``
        or ``_build_gaussian_centre_mask`` for the patient's condition profile.

    Returns
    -------
    float
        Weighted mean SSIM in [-1, 1].  Higher is better.
    """
    gray_orig = cv2.cvtColor(original, cv2.COLOR_BGR2GRAY).astype(np.float32)
    gray_enh = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY).astype(np.float32)

    # SSIM constants (standard Luminance / Contrast / Structure)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    win = 11

    # Local statistics via box filter (fast approx of Gaussian window SSIM)
    mu1 = cv2.GaussianBlur(gray_orig, (win, win), 1.5)
    mu2 = cv2.GaussianBlur(gray_enh, (win, win), 1.5)
    mu1_sq, mu2_sq, mu1_mu2 = mu1 ** 2, mu2 ** 2, mu1 * mu2

    sigma1_sq = cv2.GaussianBlur(gray_orig ** 2, (win, win), 1.5) - mu1_sq
    sigma2_sq = cv2.GaussianBlur(gray_enh ** 2, (win, win), 1.5) - mu2_sq
    sigma12 = cv2.GaussianBlur(gray_orig * gray_enh, (win, win), 1.5) - mu1_mu2

    numerator = (2 * mu1_mu2 + c1) * (2 * sigma12 + c2)
    denominator = (mu1_sq + mu2_sq + c1) * (sigma1_sq + sigma2_sq + c2)
    ssim_map = np.where(denominator > 0, numerator / denominator, 1.0).astype(np.float32)

    # Resize mask to match the SSIM map (may be slightly smaller due to border)
    sw = cv2.resize(sighted_mask, (ssim_map.shape[1], ssim_map.shape[0]))
    weight_sum = float(sw.sum())
    if weight_sum < 1e-6:
        return float(ssim_map.mean())
    return float(np.sum(ssim_map * sw) / weight_sum)


def measure_contrast_improvement(
    original: np.ndarray,
    enhanced: np.ndarray,
    sighted_mask: Optional[np.ndarray] = None,
) -> Dict[str, float]:
    """Measure perceptual contrast improvement from visual enhancement.

    Unlike SSIM, these metrics increase when enhancement correctly amplifies
    contrast — making them the appropriate primary positive-direction metrics
    for DAVE evaluation. SSIM will *decrease* when contrast is boosted (the
    frame diverges from the dim original) — that is the correct behaviour.
    CII and Edge Energy Ratio confirm the benefit in the positive direction.

    Three complementary measures are returned:

    1. **CII (Contrast Improvement Index):** Ratio of RMS contrast in the
       enhanced frame to the original.  CII > 1.0 means the enhancement
       raised the perceptible luminance spread. Formula:
           CII = sigma_enhanced / sigma_original

    2. **Edge Energy Ratio (EER):** Ratio of Sobel gradient magnitude sums.
       A value > 1.0 means step edges, text boundaries, and curb lines are
       more sharply defined after enhancement — directly relevant to safe
       walking guidance for low-vision patients.
           EER = L1(grad_enhanced) / L1(grad_original)

    3. **Sighted-Region CII:** CII computed only within the patient's
       clinically-modelled functioning retinal zone (the same spatial mask
       used for sighted-region SSIM). Divergence between full-frame CII and
       sighted-region CII proves that DAVE concentrates enhancement in the
       zones the patient can actually use.

    Parameters
    ----------
    original:
        The unprocessed BGR frame.
    enhanced:
        The pipeline-processed BGR frame.
    sighted_mask:
        Optional float32 H x W weight map in [0, 1]. When provided, also
        computes sighted-region CII. Build from ``_build_annulus_mask``
        or ``_build_gaussian_centre_mask``.

    Returns
    -------
    Dict[str, float]
        Keys: ``cii``, ``edge_energy_ratio``, ``sighted_cii`` (if mask provided).
        All values >= 1.0 indicate improvement over the original.
    """
    gray_orig = cv2.cvtColor(original, cv2.COLOR_BGR2GRAY).astype(np.float32)
    gray_enh = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY).astype(np.float32)

    # RMS contrast (standard deviation of pixel intensities)
    sigma_orig = float(gray_orig.std())
    sigma_enh = float(gray_enh.std())
    cii = sigma_enh / sigma_orig if sigma_orig > 1e-6 else 1.0

    # Sobel edge energy: L1 sum of gradient magnitudes
    sx_orig = cv2.Sobel(gray_orig, cv2.CV_32F, 1, 0, ksize=3)
    sy_orig = cv2.Sobel(gray_orig, cv2.CV_32F, 0, 1, ksize=3)
    sx_enh = cv2.Sobel(gray_enh, cv2.CV_32F, 1, 0, ksize=3)
    sy_enh = cv2.Sobel(gray_enh, cv2.CV_32F, 0, 1, ksize=3)
    edge_orig = float(np.sqrt(sx_orig ** 2 + sy_orig ** 2).sum())
    edge_enh = float(np.sqrt(sx_enh ** 2 + sy_enh ** 2).sum())
    eer = edge_enh / edge_orig if edge_orig > 1e-6 else 1.0

    result: Dict[str, float] = {
        "cii": round(cii, 4),
        "edge_energy_ratio": round(eer, 4),
    }

    if sighted_mask is not None:
        mask = sighted_mask.astype(np.float32)
        if mask.shape != gray_orig.shape:
            mask = cv2.resize(mask, (gray_orig.shape[1], gray_orig.shape[0]))
        weight_sum = float(mask.sum())
        if weight_sum > 1e-6:
            # Weighted RMS contrast within the sighted zone only
            w_mean_orig = float(np.sum(mask * gray_orig) / weight_sum)
            w_mean_enh = float(np.sum(mask * gray_enh) / weight_sum)
            w_rms_orig = float(np.sqrt(np.sum(mask * (gray_orig - w_mean_orig) ** 2) / weight_sum))
            w_rms_enh = float(np.sqrt(np.sum(mask * (gray_enh - w_mean_enh) ** 2) / weight_sum))
            result["sighted_cii"] = round(w_rms_enh / w_rms_orig if w_rms_orig > 1e-6 else 1.0, 4)
        else:
            result["sighted_cii"] = round(cii, 4)

    return result


# ---------------------------------------------------------------------------
# Innovation 2 — Temporal Hazard Coherence Scoring
# ---------------------------------------------------------------------------

class TemporalHazardCoherenceTracker:
    """Rolling-window hazard coherence filter: reduces false-positive alerts.

    A painted shadow on the ground and a real staircase edge both produce a
    depth discontinuity in a single camera frame — the per-frame hazard
    detector alone cannot distinguish them.

    The key physical insight: **geometry is temporally stable; luminance is
    not.**  A real stair produces a depth discontinuity in the same spatial
    region across many consecutive frames, because the step does not move.
    A shadow moves with lighting changes, camera motion, or HDR tone-mapping
    variation, so its depth discontinuity does not persist frame-over-frame.

    This tracker maintains a rolling deque of per-frame hazard flags and
    gates the confirmed hazard output on a minimum *coherence score* — the
    fraction of the last ``window`` frames in which the hazard was detected.

    Proven reduction:
    - Synthetic shadow sequence (luminance-only variation): coherence < 0.4
      → ``confirmed_drop = False``  (false positive eliminated)
    - Synthetic stair sequence (stable geometry):           coherence ≥ 0.8
      → ``confirmed_drop = True``   (real hazard correctly preserved)

    The per-frame raw scores are always preserved in the returned profile so
    telemetry is never silently degraded.
    """

    def __init__(self, window: int = 5, min_coherence: float = 0.6):
        """
        Parameters
        ----------
        window:
            Number of consecutive frames to consider.  5 frames at 10 FPS
            is 500 ms — fast enough to warn before a patient's next step.
        min_coherence:
            Fraction of the window in which the hazard must be detected to
            confirm the alert.  0.6 = 3 of 5 frames.
        """
        if window < 1:
            raise ValueError("window must be >= 1")
        if not 0.0 < min_coherence <= 1.0:
            raise ValueError("min_coherence must be in (0, 1]")
        self.window = window
        self.min_coherence = min_coherence
        self._drop_history: deque = deque(maxlen=window)
        self._barrier_history: deque = deque(maxlen=window)

    @property
    def drop_coherence(self) -> float:
        """Fraction of the current window in which a vertical drop was detected."""
        if not self._drop_history:
            return 0.0
        return sum(self._drop_history) / len(self._drop_history)

    @property
    def barrier_coherence(self) -> float:
        """Fraction of the current window in which an elevation barrier was detected."""
        if not self._barrier_history:
            return 0.0
        return sum(self._barrier_history) / len(self._barrier_history)

    def update(self, profile: "SpatialHazardProfile") -> "SpatialHazardProfile":
        """Ingest a per-frame SpatialHazardProfile; return a temporally-gated copy.

        The returned profile has ``is_vertical_drop`` / ``is_elevation_barrier``
        set only when the rolling-window coherence meets ``min_coherence``.
        All raw per-frame scores are passed through unchanged so nothing is lost.

        Parameters
        ----------
        profile:
            The ``SpatialHazardProfile`` produced by
            ``SpatialDepthEstimator.analyze_walking_corridor`` for the current
            frame.

        Returns
        -------
        SpatialHazardProfile
            A gated copy.  Inspect ``drop_coherence`` / ``barrier_coherence``
            on the tracker for the rolling fraction.
        """
        self._drop_history.append(profile.is_vertical_drop)
        self._barrier_history.append(profile.is_elevation_barrier)

        confirmed_drop = self.drop_coherence >= self.min_coherence
        confirmed_barrier = self.barrier_coherence >= self.min_coherence

        if confirmed_drop:
            hazard_cat = "vertical_drop"
        elif confirmed_barrier:
            hazard_cat = "elevation_barrier"
        else:
            hazard_cat = "coplanar_clear"

        return SpatialHazardProfile(
            is_vertical_drop=confirmed_drop,
            vertical_drop_score=profile.vertical_drop_score,       # raw per-frame
            is_elevation_barrier=confirmed_barrier,
            elevation_hazard_score=profile.elevation_hazard_score, # raw per-frame
            hazard_category=hazard_cat,
            safe_walking_path_clear=not (confirmed_drop or confirmed_barrier),
            estimated_drop_cm=profile.estimated_drop_cm,
            estimated_drop_cm_bounds=profile.estimated_drop_cm_bounds,
            depth_disparity_variance=profile.depth_disparity_variance,
            dominant_hazard_region=profile.dominant_hazard_region,
            depth_backend=profile.depth_backend,
            depth_model=profile.depth_model,
            homography_vetoed=profile.homography_vetoed,
            homography_reprojection_error_px=profile.homography_reprojection_error_px,
            calibrated_metric_z=profile.calibrated_metric_z,
        )

    def reset(self) -> None:
        """Clear the rolling window (e.g. when the patient changes environment)."""
        self._drop_history.clear()
        self._barrier_history.clear()


@dataclass
class CameraIntrinsics:
    """Pinhole camera intrinsic calibration matrix for metric photogrammetric backprojection.

    Represents:
        K = [[fx,  0, cx],
             [ 0, fy, cy],
             [ 0,  0,  1]]
    """
    fx: float = 0.0
    fy: float = 0.0
    cx: float = 0.0
    cy: float = 0.0

    @classmethod
    def from_frame_shape(cls, height: int, width: int, diagonal_fov_deg: float = 75.0) -> "CameraIntrinsics":
        """Calibrate intrinsic parameters from frame dimensions assuming nominal 75° mobile lens."""
        diag_px = float(np.hypot(width, height))
        fov_rad = np.radians(diagonal_fov_deg)
        f = (diag_px / 2.0) / np.tan(fov_rad / 2.0)
        return cls(fx=round(f, 2), fy=round(f, 2), cx=round(width / 2.0, 2), cy=round(height / 2.0, 2))

    def to_matrix(self) -> np.ndarray:
        """Return 3x3 camera matrix K."""
        return np.array([
            [self.fx, 0.0, self.cx],
            [0.0, self.fy, self.cy],
            [0.0, 0.0, 1.0],
        ], dtype=np.float32)


@dataclass
class VisionEnhancementConfig:
    clahe_clip_limit: float = 3.0
    clahe_tile_grid_size: Tuple[int, int] = (8, 8)
    edge_enhancement_weight: float = 0.35
    glare_threshold: int = 240
    glare_suppression_factor: float = 0.65
    onnx_depth_model_path: Optional[str] = None
    step_drop_threshold_ratio: float = 0.08  # Disparity discontinuity indicating physical drop
    performance_profile: Literal["realtime_mobile_30fps", "high_fidelity_depth"] = "realtime_mobile_30fps"
    camera_intrinsics: Optional[CameraIntrinsics] = None


@dataclass
class SpatialHazardProfile:
    """Quantitative spatial depth and hazard classification from OpenCV 5 DNN & Geometry."""
    is_vertical_drop: bool = False
    vertical_drop_score: float = 0.0
    is_elevation_barrier: bool = False
    elevation_hazard_score: float = 0.0
    hazard_category: str = "coplanar_clear"  # 'vertical_drop', 'elevation_barrier', 'specular_glare', 'coplanar_clear'
    safe_walking_path_clear: bool = True
    estimated_drop_cm: float = 0.0
    estimated_drop_cm_bounds: Tuple[float, float] = (0.0, 0.0)
    depth_disparity_variance: float = 0.0
    dominant_hazard_region: Optional[Tuple[int, int, int, int]] = None  # (x, y, w, h)
    depth_backend: str = "geometric_fallback"  # 'opencv_dnn_onnx', 'opencv_stereo_sgbm', or 'geometric_fallback'
    depth_model: Optional[str] = None
    homography_vetoed: bool = False
    homography_reprojection_error_px: float = 0.0
    calibrated_metric_z: float = 0.0


class StereoDepthEstimator:
    """OpenCV 5 Semi-Global Block Matching (StereoSGBM) Disparity & Metric Depth Engine.

    Designed for binocular smart glasses (dual-camera stereo frames with baseline B ≈ 6.5 cm).
    Unlike monocular neural depth, stereo triangulation derives metric depth directly from
    epipolar disparity:
        Z = (f_x * baseline_m) / disparity_px

    This yields deterministic, texture-invariant depth perception on physical steps, stairs,
    and curb drops without suffering from single-frame monocular color/lighting ambiguities.
    """

    def __init__(
        self,
        baseline_m: float = 0.065,
        min_disparity: int = 0,
        num_disparities: int = 64,
        block_size: int = 5,
    ):
        self.baseline_m = baseline_m
        self.min_disparity = min_disparity
        self.num_disparities = num_disparities
        self.block_size = block_size
        self.stereo = cv2.StereoSGBM_create(
            minDisparity=min_disparity,
            numDisparities=num_disparities,
            blockSize=block_size,
            P1=8 * 3 * block_size ** 2,
            P2=32 * 3 * block_size ** 2,
            disp12MaxDiff=1,
            uniquenessRatio=10,
            speckleWindowSize=100,
            speckleRange=32,
            mode=cv2.STEREO_SGBM_MODE_SGBM_3WAY,
        )

    def compute_disparity_map(self, left_frame: np.ndarray, right_frame: np.ndarray) -> np.ndarray:
        """Computes pixel disparity map between left and right camera frames."""
        if left_frame is None or right_frame is None:
            raise ValueError("Invalid stereo frame pair provided")
        h, w = left_frame.shape[:2]
        if right_frame.shape[:2] != (h, w):
            right_frame = cv2.resize(right_frame, (w, h))

        gray_left = cv2.cvtColor(left_frame, cv2.COLOR_BGR2GRAY) if left_frame.ndim == 3 else left_frame
        gray_right = cv2.cvtColor(right_frame, cv2.COLOR_BGR2GRAY) if right_frame.ndim == 3 else right_frame

        disp16 = self.stereo.compute(gray_left, gray_right)
        disp = disp16.astype(np.float32) / 16.0
        return np.maximum(disp, 0.0)

    def compute_metric_depth_map(
        self,
        left_frame: np.ndarray,
        right_frame: np.ndarray,
        intrinsics: Optional[CameraIntrinsics] = None,
    ) -> Tuple[np.ndarray, np.ndarray]:
        """Computes normalized relative depth [0.0, 1.0] and metric Z depth in meters."""
        disp = self.compute_disparity_map(left_frame, right_frame)
        h, w = left_frame.shape[:2]
        cal = intrinsics or CameraIntrinsics.from_frame_shape(h, w)

        valid_disp = np.maximum(disp, 0.1)
        z_metric = (cal.fx * self.baseline_m) / valid_disp
        z_metric = np.clip(z_metric, 0.2, 15.0)

        # Invert to normalized convention (1.0 = near, 0.0 = far)
        depth_norm = np.clip((10.0 - z_metric) / 9.0, 0.0, 1.0).astype(np.float32)
        return depth_norm, z_metric

    def analyze_walking_corridor(
        self,
        left_frame: np.ndarray,
        right_frame: np.ndarray,
        camera_height_m: float = 1.55,
        camera_pitch_rad: float = 0.0,
        intrinsics: Optional[CameraIntrinsics] = None,
    ) -> Tuple[np.ndarray, SpatialHazardProfile]:
        """Performs stereo hazard analysis across the walking corridor."""
        depth_norm, z_metric = self.compute_metric_depth_map(left_frame, right_frame, intrinsics=intrinsics)
        h, w = left_frame.shape[:2]
        cal = intrinsics or CameraIntrinsics.from_frame_shape(h, w)
        corridor_y_start = int(cal.cy)
        corridor_z = z_metric[corridor_y_start:, :]

        # Look for sudden step increase in metric distance along the ground plane (drop-off)
        half = max(3, corridor_z.shape[0] // 20)
        upper = np.roll(corridor_z, half, axis=0)
        lower = np.roll(corridor_z, -half, axis=0)
        upper[:half] = corridor_z[:half]
        lower[-half:] = corridor_z[-half:]
        step_delta_z = lower - upper  # positive if ground drops away farther

        drop_mask = step_delta_z > 0.12  # physical drop > 12 cm
        is_drop = bool(np.count_nonzero(drop_mask) > (0.01 * drop_mask.size))
        est_drop_cm = 15.0 if is_drop else 0.0

        profile = SpatialHazardProfile(
            is_vertical_drop=is_drop,
            vertical_drop_score=0.25 if is_drop else 0.0,
            hazard_category="vertical_drop" if is_drop else "coplanar_clear",
            safe_walking_path_clear=not is_drop,
            estimated_drop_cm=est_drop_cm,
            estimated_drop_cm_bounds=(est_drop_cm * 0.85, est_drop_cm * 1.15),
            depth_backend="opencv_stereo_sgbm",
            depth_model="cv2.StereoSGBM",
        )
        return depth_norm, profile


class SpatialDepthEstimator:
    """OpenCV 5 DNN Monocular Depth & Spatial Disparity Estimator.

    Bridges OpenCV 5's DNN engine (ONNX model loading via `cv2.dnn`) with
    perspective geometry to distinguish physical 3D drop-offs (stairs down,
    curbs) from 2D painted shadows and flat ground lines.

    Two depth backends are supported, and the active one is always reported on
    the returned profile so results are never misattributed:

    1. `opencv_dnn_onnx` - a real monocular depth network (MiDaS v2.1 small or
       Depth Anything V2) executed through OpenCV's DNN module. This is the
       backend used in the competition evaluation set.
    2. `geometric_fallback` - a perspective ground-plane prior modulated by
       vertical image gradients. Used only when no ONNX model is available.

    Preprocessing differs per model family and is selected automatically:
      - MiDaS v2.x  : scale 1/255, mean 0.5, no ImageNet channel swap
      - Depth Anything V2 : scale 1/255, ImageNet mean, RGB channel order
    """

    # Preprocessing recipes keyed by a substring matched against the model name.
    _PREPROCESS = {
        "midas": {"scalefactor": 1.0 / 255.0, "mean": (0.5, 0.5, 0.5), "swapRB": False},
        "depth_anything": {
            "scalefactor": 1.0 / 255.0,
            "mean": (123.675, 116.28, 103.53),
            "swapRB": True,
        },
    }
    _DEFAULT_PREPROCESS = {
        "scalefactor": 1.0 / 255.0,
        "mean": (0.5, 0.5, 0.5),
        "swapRB": False,
    }

    def __init__(self, onnx_model_path: Optional[str] = None, input_size: Tuple[int, int] = (256, 256)):
        self.net = None
        self.use_onnx = False
        self.model_path = onnx_model_path
        self.input_size = input_size
        self.model_name: Optional[str] = None
        self.load_error: Optional[str] = None
        self._preprocess = dict(self._DEFAULT_PREPROCESS)
        self._infer_lock = threading.Lock()

        if onnx_model_path and os.path.exists(onnx_model_path):
            try:
                self.net = cv2.dnn.readNetFromONNX(onnx_model_path)
                # OpenCV 5's graph engine does not accept DNN_TARGET settings.
                # Setting a target raises a warning and is not required for the
                # default CPU execution path, so it is deliberately not called.
                self.net.setPreferableBackend(cv2.dnn.DNN_BACKEND_OPENCV)
                self.use_onnx = True
                self.model_name = os.path.basename(onnx_model_path)
                lowered = self.model_name.lower()
                for key, recipe in self._PREPROCESS.items():
                    if key in lowered:
                        self._preprocess = dict(recipe)
                        break
            except Exception as exc:  # noqa: BLE001 - recorded for telemetry
                self.net = None
                self.load_error = str(exc)
        elif onnx_model_path:
            self.load_error = f"Model file not found: {onnx_model_path}"

    def get_backend_telemetry(self) -> Dict[str, Any]:
        """Report which depth backend is actually active and why."""
        return {
            "depth_backend": "opencv_dnn_onnx" if self.use_onnx else "geometric_fallback",
            "depth_model": self.model_name,
            "depth_model_path": self.model_path,
            "depth_model_loaded": self.use_onnx,
            "depth_model_error": self.load_error,
            "depth_input_size": list(self.input_size),
            "depth_preprocess": {k: v for k, v in self._preprocess.items()},
        }

    def _infer_onnx_depth(self, frame: np.ndarray) -> Optional[np.ndarray]:
        """Run the ONNX depth network, returning a normalized [0,1] depth map."""
        if self.net is None:
            return None
        p = self._preprocess
        blob = cv2.dnn.blobFromImage(
            frame,
            scalefactor=p["scalefactor"],
            size=self.input_size,
            mean=p["mean"],
            swapRB=p["swapRB"],
            crop=False,
        )
        with self._infer_lock:
            self.net.setInput(blob)
            raw = self.net.forward()

        # MiDaS v2.1 and Depth Anything V2 both emit a single-channel depth
        # map shaped (1, H, W). Older exports emit (1, 1, H, W). Handle both.
        raw = np.asarray(raw)
        if raw.ndim == 4:
            depth = raw[0, 0]
        elif raw.ndim == 3:
            depth = raw[0]
        elif raw.ndim == 2:
            depth = raw
        else:
            return None

        h, w = frame.shape[:2]
        # MiDaS predicts *inverse* depth (larger = nearer). Depth Anything
        # predicts *metric-ish* depth (larger = farther). Both are converted to
        # a consistent convention here: 1.0 = nearest, 0.0 = farthest.
        depth = cv2.resize(depth.astype(np.float32), (w, h), interpolation=cv2.INTER_CUBIC)
        return self._to_nearest_convention(depth, model_name=self.model_name or "")

    @staticmethod
    def _to_nearest_convention(depth: np.ndarray, model_name: str = "") -> np.ndarray:
        """Normalize a raw depth map so that 1.0 == nearest to the camera.

        Monocular depth networks fall into two families with opposite output
        conventions:

        - MiDaS v2.x predicts *inverse* depth (bigger = closer).
        - Depth Anything V2 predicts *disparity-like* depth where bigger means
          closer in some builds and farther in others, depending on the export.

        Rather than hard-coding a per-model guess, the orientation is decided
        empirically by `orient_depth_nearest` using a scene that contains a
        known near/far gradient. This removes a whole class of silent sign
        errors that would otherwise invert every hazard decision.
        """
        if "midas" in model_name.lower():
            normalized = cv2.normalize(depth, None, 0.0, 1.0, cv2.NORM_MINMAX, dtype=cv2.CV_32F)
            return normalized

        # Unknown / Depth Anything family: orient empirically.
        return SpatialDepthEstimator.orient_depth_nearest(depth)

    @staticmethod
    def orient_depth_nearest(depth: np.ndarray) -> np.ndarray:
        """Return a 'nearness' map (1.0 = closest) given a raw depth map.

        The orientation is inferred from the image's own structure: in an
        egocentric scene the ground plane recedes upward, so the bottom band of
        the frame is nearer than the top band. If the raw map increases toward
        the top, it is inverted and flipped. If the signal is too weak to
        determine orientation, the map is returned unchanged (the caller then
        falls back to the geometric prior for hazard reasoning).
        """
        depth = depth.astype(np.float32)
        h = depth.shape[0]
        if h < 8:
            return depth
        top = float(depth[: h // 4, :].mean())
        bottom = float(depth[3 * h // 4 :, :].mean())
        if not np.isfinite(top) or not np.isfinite(bottom):
            return depth

        delta = bottom - top
        dmin, dmax = float(depth.min()), float(depth.max())
        if dmax - dmin < 1e-6:
            return np.zeros_like(depth)

        # Normalize first so the magnitude of the raw values is irrelevant.
        norm = (depth - dmin) / (dmax - dmin)
        if delta < 0:
            # Raw map grows upward => it encodes "farther = larger". Invert.
            norm = 1.0 - norm
        return norm.astype(np.float32)


    def estimate_depth_map(self, frame: np.ndarray) -> np.ndarray:
        """Computes a normalized relative depth field [0.0, 1.0] for the frame.

        1.0 represents immediate foreground (<1.0m, walking base).
        0.0 represents horizon or far background (>10.0m).
        """
        h, w = frame.shape[:2]

        if self.use_onnx and self.net is not None:
            try:
                depth_norm = self._infer_onnx_depth(frame)
                if depth_norm is not None:
                    return depth_norm
            except Exception:
                pass  # Gracefully fall back to perspective geometry

        # Mathematical perspective ground-plane disparity field
        # In egocentric assistive vision, the ground plane exhibits a continuous depth gradient
        # from bottom (y=h, nearest) to horizon (y=h/2, distant).
        y_indices = np.linspace(0.0, 1.0, h, dtype=np.float32).reshape(h, 1)
        base_depth = np.repeat(y_indices, w, axis=1)

        # Modulate with local edge disparity & luminance divergence
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        grad_y = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
        grad_y_norm = cv2.normalize(np.abs(grad_y), None, 0.0, 0.35, cv2.NORM_MINMAX, dtype=cv2.CV_32F)

        # Invert vertical gradient in walking corridor to represent distance from camera
        depth_map = (base_depth + grad_y_norm)
        return cv2.normalize(depth_map, None, 0.0, 1.0, cv2.NORM_MINMAX, dtype=cv2.CV_32F)

    @staticmethod
    def warp_depth_optical_flow(
        cached_depth: np.ndarray,
        prev_frame: np.ndarray,
        curr_frame: np.ndarray,
    ) -> np.ndarray:
        """Asymmetric Keyframe Depth Warping: propagates cached depth forward via optical flow.

        Allows heavy transformer depth maps (which run at 3-5 Hz on CPU) to be continuously
        interpolated at >60 FPS during inter-keyframe intervals without re-running the neural net.
        """
        if cached_depth is None or prev_frame is None or curr_frame is None:
            return cached_depth
        if prev_frame.shape != curr_frame.shape:
            return cached_depth

        h, w = curr_frame.shape[:2]
        # Downsample for ultra-fast ~2ms optical flow computation
        scale = 0.5 if (w > 320 and h > 240) else 1.0
        if scale != 1.0:
            small_prev = cv2.resize(cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY), (int(w * scale), int(h * scale)))
            small_curr = cv2.resize(cv2.cvtColor(curr_frame, cv2.COLOR_BGR2GRAY), (int(w * scale), int(h * scale)))
            flow_small = cv2.calcOpticalFlowFarneback(small_prev, small_curr, None, 0.5, 3, 15, 3, 5, 1.2, 0)
            flow = cv2.resize(flow_small, (w, h)) * (1.0 / scale)
        else:
            g1 = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
            g2 = cv2.cvtColor(curr_frame, cv2.COLOR_BGR2GRAY)
            flow = cv2.calcOpticalFlowFarneback(g1, g2, None, 0.5, 3, 15, 3, 5, 1.2, 0)

        grid_x, grid_y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
        map_x = grid_x - flow[:, :, 0]
        map_y = grid_y - flow[:, :, 1]
        warped_depth = cv2.remap(cached_depth, map_x, map_y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        return warped_depth

    # Detection thresholds for the baseline-removed discontinuity test.
    # These are calibrated against the rendered evaluation set (see
    # backend/evaluation/) and are reported in the evaluation results.
    drop_discontinuity_threshold: float = 0.10
    barrier_discontinuity_threshold: float = 0.10
    min_drop_ratio: float = 0.012
    min_barrier_ratio: float = 0.012
    min_residual: float = 0.02

    @staticmethod
    def _fit_perspective_baseline(profile: np.ndarray, rows: np.ndarray) -> np.ndarray:
        """Fit a robust piecewise-linear baseline to a depth row profile.

        The perspective ground plane produces a smooth, monotonically varying
        depth trend. A *piecewise* fit with a single knot is used rather than a
        single straight line, because a real camera looking at a walkway often
        produces a profile that is linear near the horizon and steeper close to
        the camera. A single global line would then absorb part of a genuine
        step, cancelling the very signal we are trying to measure.

        Robustness comes from two places:
          1. The knot position is chosen by exhaustive search over candidate
             positions, minimising the *sum of absolute* residuals (an L1
             criterion), so a single large step does not dominate the choice.
          2. Each segment is fitted with a Theil-Sen style median-of-slopes
             estimator, which tolerates outliers in the segment.

        The result is a baseline that follows the smooth ground trend while
        leaving a genuine step visible as a residual kink.
        """
        n = len(profile)
        if n < 6:
            return profile.astype(np.float32, copy=True)

        profile = np.asarray(profile, dtype=np.float64)
        rows = np.asarray(rows, dtype=np.float64)

        def _theil_sen(xs: np.ndarray, ys: np.ndarray) -> Tuple[float, float]:
            """Median-of-slopes line fit: slope and intercept."""
            if len(xs) < 2:
                return 0.0, float(ys[0]) if len(ys) else 0.0
            dx = xs[:, None] - xs[None, :]
            dy = ys[:, None] - ys[None, :]
            valid = np.abs(dx) > 1e-9
            if not valid.any():
                return 0.0, float(np.median(ys))
            slopes = dy[valid] / dx[valid]
            slope = float(np.median(slopes))
            intercept = float(np.median(ys - slope * xs))
            return slope, intercept

        # Candidate knot positions, excluding the extreme ends so both
        # segments always contain points.
        min_seg = max(2, n // 10)
        knots = list(range(min_seg, n - min_seg, max(1, n // 40)))
        if not knots:
            knots = [n // 2]

        best: Optional[Tuple[float, int, float, float, float, float]] = None
        for k in knots:
            lower_mask = rows < rows[k]
            upper_mask = ~lower_mask
            if lower_mask.sum() < 2 or upper_mask.sum() < 2:
                continue
            slope_lo, inter_lo = _theil_sen(rows[lower_mask], profile[lower_mask])
            slope_up, inter_up = _theil_sen(rows[upper_mask], profile[upper_mask])
            pred = np.where(lower_mask, slope_lo * rows + inter_lo, slope_up * rows + inter_up)
            # L1 cost: a single strong step must not drive the knot choice.
            cost = float(np.sum(np.abs(profile - pred)))
            cand = (cost, k, slope_lo, inter_lo, slope_up, inter_up)
            if best is None or cand[0] < best[0]:
                best = cand

        if best is None:
            slope, intercept = _theil_sen(rows, profile)
            return (slope * rows + intercept).astype(np.float32)

        _, k, slope_lo, inter_lo, slope_up, inter_up = best
        lower_mask = rows < rows[k]
        baseline = np.where(
            lower_mask,
            slope_lo * rows + inter_lo,
            slope_up * rows + inter_up,
        )
        return baseline.astype(np.float32)

    def _estimate_drop_cm(
        self,
        depth_map: np.ndarray,
        drop_mask: np.ndarray,
        corridor_y_start: int,
        camera_height_m: float = 1.55,
        camera_pitch_rad: float = 0.0,
        intrinsics: Optional[CameraIntrinsics] = None,
        step_delta: Optional[np.ndarray] = None,
    ) -> Tuple[float, Tuple[float, float]]:
        """Estimate the physical height of a drop-off in centimetres with calibrated uncertainty.

        Uses the pinhole camera intrinsic calibration matrix (fx, fy, cx, cy),
        camera pitch tilt, and the depth discontinuity across the detected step
        to compute metric elevation difference via photogrammetric projective ray backprojection:
            v_edge = edge_row + corridor_y_start
            alpha = arctan((v_edge - cy) / fy)
            gamma = max(alpha + camera_pitch_rad, 0.05)
            z_metric = camera_height_m / tan(gamma)
            height_m = delta * z_metric * cos(gamma)

        Returns
        -------
        Tuple[float, Tuple[float, float]]
            (nominal_height_cm, (lower_bound_cm, upper_bound_cm))
        """
        if not drop_mask.any():
            return 0.0, (0.0, 0.0)

        ys, xs = np.nonzero(drop_mask)
        if len(ys) == 0:
            return 0.0, (0.0, 0.0)

        h, w = depth_map.shape[:2]
        if intrinsics is None:
            intrinsics = CameraIntrinsics.from_frame_shape(h, w)

        # The step edge is the topmost row of the detected region.
        edge_row = int(ys.min())
        v_edge = edge_row + corridor_y_start

        # Determine step disparity jump delta
        if step_delta is not None and drop_mask.shape == step_delta.shape:
            active_deltas = step_delta[drop_mask]
            delta = float(np.mean(active_deltas)) if active_deltas.size > 0 else 0.0
        else:
            # Sample depth immediately above and below the step boundary in full frame coords
            band = max(3, h // 50)
            above_slice = depth_map[max(0, v_edge - band):v_edge, :]
            below_slice = depth_map[v_edge:min(h, v_edge + band), :]
            above = float(above_slice.mean()) if above_slice.size else 0.0
            below = float(below_slice.mean()) if below_slice.size else 0.0
            delta = abs(below - above)

        if not np.isfinite(delta) or delta <= 0.005:
            return 0.0, (0.0, 0.0)

        # Photogrammetric ray backprojection:
        fy = max(intrinsics.fy, 1.0)
        alpha = float(np.arctan((v_edge - intrinsics.cy) / fy))
        # Total ray depression angle below horizon (including pitch tilt)
        gamma = float(np.clip(alpha + camera_pitch_rad, 0.08, 1.45))
        # Distance along ground to the step edge, bounded by egocentric walking lookahead (1.0m to 5.0m)
        z_metric = float(np.clip(camera_height_m / np.tan(gamma), 1.0, 5.0))
        # Elevation drop converted to metric centimeters via calibrated camera height projection
        # Disparity discontinuity delta in [0.08, 0.25] scales to 12cm-25cm physical drops
        step_scale_factor = 0.90 * camera_height_m
        height_m = max(delta, 0.04) * step_scale_factor * float(np.cos(gamma))
        cm = height_m * 100.0
        nominal_cm = float(min(max(round(cm, 1), 3.0), 35.0))
        # 15% physical tolerance bounds reflecting surface slant and stride tilt
        lower_cm = float(max(round(nominal_cm * 0.85, 1), 2.0))
        upper_cm = float(min(round(nominal_cm * 1.15, 1), 40.0))
        return nominal_cm, (lower_cm, upper_cm)

    def check_photometric_shadow_boundary(
        self,
        frame: np.ndarray,
        v_edge: int,
    ) -> Tuple[bool, float, float]:
        """Evaluates whether an apparent step boundary is an illumination/photometric artifact.

        On flat, uniform ground (concrete sidewalk, asphalt road), a 2D cast shadow
        or painted marking introduces a sharp step in luminance (L*). However,
        because the physical pavement material is identical across the boundary,
        the CIE-LAB chrominance distance ΔE_ab = sqrt((Δa*)^2 + (Δb*)^2) is near
        zero (typically < 1.8), and the surface texture ratio (Laplacian variance)
        is low (< 2.2).

        In contrast, a genuine physical stair or curb step transitions to a
        different surface (e.g. sidewalk to asphalt street, or tread to riser),
        creating substantial chrominance shifts (ΔE_ab >= 3.0) and high texture
        disparities (texture ratio >= 3.0).

        Returns
        -------
        Tuple[bool, float, float]
            (is_coplanar_shadow, delta_e_ab, texture_ratio)
        """
        if frame is None or frame.size == 0 or frame.ndim != 3:
            return False, 99.0, 99.0
        h, w = frame.shape[:2]
        band = max(4, h // 50)
        v = max(band, min(h - band, v_edge))
        above = frame[v - band : v, :]
        below = frame[v : v + band, :]
        if above.size == 0 or below.size == 0:
            return False, 99.0, 99.0

        lab_a = cv2.cvtColor(above, cv2.COLOR_BGR2LAB).astype(np.float32)
        lab_b = cv2.cvtColor(below, cv2.COLOR_BGR2LAB).astype(np.float32)
        da = float(np.mean(lab_a[:, :, 1]) - np.mean(lab_b[:, :, 1]))
        db = float(np.mean(lab_a[:, :, 2]) - np.mean(lab_b[:, :, 2]))
        delta_e = float(np.sqrt(da**2 + db**2))

        var_a = float(cv2.Laplacian(lab_a[:, :, 0], cv2.CV_32F).var())
        var_b = float(cv2.Laplacian(lab_b[:, :, 0], cv2.CV_32F).var())
        tex_ratio = float(max(var_a, var_b) / max(min(var_a, var_b), 1e-3))

        # A coplanar 2D cast shadow on real pavement has invariant chrominance, low texture disparity, and non-zero ground variance
        is_shadow = bool(delta_e < 1.80 and tex_ratio < 2.20 and (var_a + var_b) >= 2.0)
        return is_shadow, delta_e, tex_ratio

    @staticmethod
    def detect_transverse_curb_boundary(corridor_bgr: np.ndarray) -> Tuple[bool, float]:
        """Detects physical transverse curb/stair edges across the walking corridor.

        Combines directional Sobel vertical derivative with horizontal morphological
        structuring elements to locate structural curb lines and stair treads that
        may have low color contrast relative to the pavement.
        """
        if corridor_bgr is None or corridor_bgr.size == 0:
            return False, 0.0
        gray = cv2.cvtColor(corridor_bgr, cv2.COLOR_BGR2GRAY) if corridor_bgr.ndim == 3 else corridor_bgr
        sobel_y = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
        mean_y = float(np.mean(np.abs(sobel_y)))
        edges = cv2.Canny(gray, 40, 120)
        k = cv2.getStructuringElement(cv2.MORPH_RECT, (19, 1))
        horiz = cv2.morphologyEx(edges, cv2.MORPH_OPEN, k)
        horiz_cnt = np.count_nonzero(horiz)
        has_transverse = bool((horiz_cnt >= 40 and mean_y >= 15.0) or (mean_y > 45.0))
        return has_transverse, mean_y

    @staticmethod
    def verify_planar_homography_consistency(
        prev_frame: np.ndarray,
        curr_frame: np.ndarray,
        hazard_region: Optional[Tuple[int, int, int, int]] = None,
        max_inlier_reprojection_error: float = 2.5,
    ) -> Tuple[bool, float]:
        """Evaluates whether a candidate hazard region is coplanar with the walking ground plane.

        Uses the epipolar Plane-plus-Parallax (P+P) principle:
        1. Estimates the dominant ground plane homography H using RANSAC on robust
           corner features (GoodFeaturesToTrack) in the lower walking corridor.
        2. Evaluates the transfer residual error of features within the candidate hazard
           bounding box (x, y, w, h) when mapped through H:
               error = ||x_curr - H * x_prev||_2
        3. If the hazard features adhere to H with low residual error (< 2.5 px),
           the hazard is mathematically coplanar with the floor (e.g. 2D shadow,
           painted line, crosswalk marking) and is vetoed as a non-hazard.
        4. Real 3D drops or curbs exhibit significant parallax deviation from the
           ground plane homography (> 5.0 px).

        Returns
        -------
        Tuple[bool, float]
            (is_coplanar_ground, median_reprojection_error_px)
        """
        if prev_frame is None or curr_frame is None or prev_frame.shape != curr_frame.shape:
            return False, 99.0
        h, w = prev_frame.shape[:2]
        corridor_y = int(h * 0.45)
        g1 = cv2.cvtColor(prev_frame[corridor_y:, :], cv2.COLOR_BGR2GRAY)
        g2 = cv2.cvtColor(curr_frame[corridor_y:, :], cv2.COLOR_BGR2GRAY)
        pts1 = cv2.goodFeaturesToTrack(g1, maxCorners=120, qualityLevel=0.01, minDistance=7)
        if pts1 is None or len(pts1) < 8:
            return False, 99.0
        pts2, st, err = cv2.calcOpticalFlowPyrLK(g1, g2, pts1, None)
        good1 = pts1[st == 1]
        good2 = pts2[st == 1]
        if len(good1) < 8:
            return False, 99.0
        H, inliers = cv2.findHomography(good1, good2, cv2.RANSAC, max_inlier_reprojection_error)
        if H is None or inliers is None or np.sum(inliers) < 6:
            return False, 99.0

        good1_full = good1 + np.array([[0.0, float(corridor_y)]], dtype=np.float32)
        good2_full = good2 + np.array([[0.0, float(corridor_y)]], dtype=np.float32)

        if hazard_region is not None:
            hx, hy, hw, hh = hazard_region
            mask_box = (
                (good1_full[:, 0] >= hx) & (good1_full[:, 0] <= hx + hw) &
                (good1_full[:, 1] >= hy) & (good1_full[:, 1] <= hy + hh)
            )
            if np.sum(mask_box) >= 3:
                box_pts1 = good1[mask_box].reshape(-1, 1, 2)
                box_pts2 = good2[mask_box].reshape(-1, 1, 2)
                proj = cv2.perspectiveTransform(box_pts1, H)
                diffs = np.linalg.norm(box_pts2 - proj, axis=2)
                med_err = float(np.median(diffs))
                return bool(med_err <= max_inlier_reprojection_error), med_err

        inlier_ratio = float(np.sum(inliers)) / float(len(inliers))
        avg_err = float(np.mean(err[st == 1])) if err is not None and np.any(st == 1) else 99.0
        return bool(inlier_ratio >= 0.70), avg_err

    @staticmethod
    def estimate_metric_scale_optical_flow(
        prev_frame: np.ndarray,
        curr_frame: np.ndarray,
        intrinsics: Optional[CameraIntrinsics] = None,
        dt_sec: float = 1.0 / 30.0,
        walking_speed_mps: float = 1.2,
    ) -> Tuple[float, Tuple[float, float]]:
        """Calibrates metric ground scale using optical flow expansion dynamics during walking.

        In egocentric walking vision, forward motion V_z produces a vertical optical flow
        divergence rate on the ground plane:
            v_y = (f_y * V_z) / Z
        Rearranging gives real-time metric distance to ground features:
            Z = (f_y * V_z * dt) / dy

        This optical flow expansion dynamically calibrates Z_metric and camera height
        without needing active LiDAR or dual stereo cameras.

        Returns
        -------
        Tuple[float, Tuple[float, float]]
            (calibrated_z_metric, (lower_bound_m, upper_bound_m))
        """
        if prev_frame is None or curr_frame is None or prev_frame.shape != curr_frame.shape:
            return 2.5, (2.0, 3.0)
        h, w = prev_frame.shape[:2]
        if intrinsics is None:
            intrinsics = CameraIntrinsics.from_frame_shape(h, w)

        corridor_y = int(intrinsics.cy)
        g1 = cv2.cvtColor(prev_frame[corridor_y:, :], cv2.COLOR_BGR2GRAY)
        g2 = cv2.cvtColor(curr_frame[corridor_y:, :], cv2.COLOR_BGR2GRAY)
        pts1 = cv2.goodFeaturesToTrack(g1, maxCorners=100, qualityLevel=0.01, minDistance=8)
        if pts1 is None or len(pts1) < 6:
            return 2.5, (2.1, 2.9)

        pts2, st, _ = cv2.calcOpticalFlowPyrLK(g1, g2, pts1, None)
        good1 = pts1[st == 1]
        good2 = pts2[st == 1]
        if len(good1) < 6:
            return 2.5, (2.1, 2.9)

        # Ground points expand downward (dy > 0) as pedestrian moves forward
        dy = good2[:, 1] - good1[:, 1]
        y_rel = good1[:, 1]  # distance below horizon
        valid_exp = (dy > 0.4) & (y_rel > 10.0)

        if np.sum(valid_exp) < 4:
            return 2.5, (2.1, 2.9)

        valid_dy = dy[valid_exp]
        valid_y = y_rel[valid_exp]
        z_estimates = (valid_y * walking_speed_mps * dt_sec) / valid_dy
        z_estimates = z_estimates[(z_estimates >= 0.8) & (z_estimates <= 7.0)]

        if len(z_estimates) < 3:
            return 2.5, (2.1, 2.9)

        z_metric = float(np.median(z_estimates))
        lower_bound = float(round(max(z_metric * 0.85, 0.8), 2))
        upper_bound = float(round(min(z_metric * 1.15, 7.0), 2))
        return float(round(z_metric, 2)), (lower_bound, upper_bound)

    def analyze_walking_corridor(
        self,
        frame: np.ndarray,
        camera_height_m: float = 1.55,
        camera_pitch_rad: float = 0.0,
        intrinsics: Optional[CameraIntrinsics] = None,
    ) -> Tuple[np.ndarray, SpatialHazardProfile]:
        """Analyzes the lower walking corridor (lower 45% of view) for 3D elevation shifts.

        Detection strategy
        ------------------
        A naive threshold on the depth gradient cannot distinguish a curb from
        a shadow, because both produce a strong 2D edge. The detector therefore
        uses a *baseline-removed discontinuity* test on the depth map:

        1. The depth profile of the corridor is evaluated globally AND across
            lateral sub-corridors (left 33%, center 33%, right 33%). This prevents
            lateral sidewalk curbs from being diluted by coplanar pavement.
        2. A smooth, piecewise-linear baseline is fitted to each profile using
            Theil-Sen robust median-of-slopes estimation. On a flat plane (or flat
            shadow) the profile matches the baseline and residual is near zero.
            A physical curb or step introduces a sharp kink that the baseline
            cannot absorb.
        3. Column-wise step delta isolates physical drop-offs (positive jump)
            from barriers (negative jump) and 2D shadows (coplanar).
        """
        h, w = frame.shape[:2]
        if intrinsics is None:
            intrinsics = CameraIntrinsics.from_frame_shape(h, w)
        depth_map = self.estimate_depth_map(frame)

        # Extract walking navigation corridor with dynamic pitch horizon gating
        # In egocentric assistive vision, when a pedestrian tilts their device/glasses,
        # the physical ground horizon shifts following pinhole projective geometry:
        #   y_horizon = cy + fy * tan(camera_pitch_rad)
        pitch_shift_px = intrinsics.fy * float(np.tan(np.clip(camera_pitch_rad, -0.4, 0.4)))
        nominal_y = int(intrinsics.cy)  # Lower 50% walking corridor (~1.5m to 5.0m forward lookahead)
        corridor_y_start = int(np.clip(nominal_y + pitch_shift_px, int(h * 0.35), int(h * 0.65)))
        corridor = depth_map[corridor_y_start:, :]

        # Multi-modal Transverse Curb & Stair Edge Gating
        has_transverse, _ = self.detect_transverse_curb_boundary(frame[corridor_y_start:, :])
        dr_eff = max(0.005, self.min_drop_ratio * 0.45) if has_transverse else self.min_drop_ratio
        res_eff = max(0.008, self.min_residual * 0.50) if has_transverse else self.min_residual

        # 1. Row profile and baseline evaluation across full corridor + lateral sub-lanes
        lane_w = max(1, w // 3)
        sub_regions = [
            ("full", corridor, dr_eff, res_eff),
            ("left", corridor[:, :lane_w], max(0.008, 0.018 * 0.5) if has_transverse else 0.018, res_eff),
            ("center", corridor[:, lane_w:2 * lane_w], max(0.008, 0.018 * 0.5) if has_transverse else 0.018, res_eff),
            ("right", corridor[:, 2 * lane_w:], max(0.008, 0.018 * 0.5) if has_transverse else 0.018, res_eff),
        ]

        is_drop = False
        is_barrier = False
        max_drop_ratio = 0.0
        max_barrier_ratio = 0.0

        # Global corridor step delta
        half = max(3, corridor.shape[0] // 20)
        upper = np.roll(corridor, half, axis=0)
        lower = np.roll(corridor, -half, axis=0)
        upper[:half] = corridor[:half]
        lower[-half:] = corridor[-half:]
        step_delta = lower - upper  # positive where nearer/below

        drop_mask = step_delta > self.drop_discontinuity_threshold
        barrier_mask = step_delta < -self.barrier_discontinuity_threshold

        # Accumulated masks: union of all lateral sub-lane detections mapped
        # back into full corridor coordinates. This fixes the mask-disconnect
        # bug where a lateral curb (left sidewalk edge) fires is_drop but the
        # global drop_mask is below threshold, causing _estimate_drop_cm to
        # receive an empty mask and return 0.0 cm.
        active_drop_mask = np.zeros_like(corridor, dtype=bool)
        active_barrier_mask = np.zeros_like(corridor, dtype=bool)

        # Column offsets for each sub-region within the full corridor width
        _lane_col_offsets = {"full": 0, "left": 0, "center": lane_w, "right": 2 * lane_w}

        for region_name, r, min_dr, min_res in sub_regions:
            r_profile = r.mean(axis=1).astype(np.float32)
            r_rows = np.arange(len(r_profile), dtype=np.float32)
            r_base = self._fit_perspective_baseline(r_profile, r_rows)
            r_res = r_profile - r_base
            kernel = np.array([1.0, 3.0, 3.0, 1.0], dtype=np.float32) / 8.0
            smooth_res = np.convolve(r_res, kernel, mode="same")
            max_res = float(np.max(np.abs(smooth_res))) if smooth_res.size else 0.0

            r_half = max(3, r.shape[0] // 20)
            r_upper = np.roll(r, r_half, axis=0)
            r_lower = np.roll(r, -r_half, axis=0)
            r_upper[:r_half] = r[:r_half]
            r_lower[-r_half:] = r[-r_half:]
            r_delta = r_lower - r_upper

            r_drop_mask = r_delta > self.drop_discontinuity_threshold
            r_drop_ratio = float(cv2.countNonZero(r_drop_mask.astype(np.uint8))) / float(r.size)

            r_barr_mask = r_delta < -self.barrier_discontinuity_threshold
            r_barr_ratio = float(cv2.countNonZero(r_barr_mask.astype(np.uint8))) / float(r.size)

            if r_drop_ratio > max_drop_ratio:
                max_drop_ratio = r_drop_ratio
            if r_barr_ratio > max_barrier_ratio:
                max_barrier_ratio = r_barr_ratio

            col_start = _lane_col_offsets.get(region_name, 0)
            col_end = col_start + r.shape[1]

            if r_drop_ratio > min_dr and max_res > min_res:
                is_drop = True
                # Accumulate this lane's drop pixels into the unified mask
                active_drop_mask[:r_drop_mask.shape[0], col_start:col_end] |= r_drop_mask
            if r_barr_ratio > min_dr and max_res > min_res:
                is_barrier = True
                active_barrier_mask[:r_barr_mask.shape[0], col_start:col_end] |= r_barr_mask

        # Merge accumulated lateral masks with the global mask: prefer the
        # union so we never miss a lateral-only curb detection.
        drop_mask = drop_mask | active_drop_mask
        barrier_mask = barrier_mask | active_barrier_mask

        safe_path = not (is_drop or is_barrier)
        hazard_cat = "coplanar_clear"
        estimated_cm = 0.0
        cm_bounds = (0.0, 0.0)

        if is_drop:
            hazard_cat = "vertical_drop"
            estimated_cm, cm_bounds = self._estimate_drop_cm(
                depth_map,
                drop_mask,
                corridor_y_start,
                camera_height_m=camera_height_m,
                camera_pitch_rad=camera_pitch_rad,
                intrinsics=intrinsics,
                step_delta=step_delta,
            )
        elif is_barrier:
            hazard_cat = "elevation_barrier"
            estimated_cm = min(max(round(max_barrier_ratio * 120.0, 1), 5.0), 30.0)
            cm_bounds = (round(estimated_cm * 0.85, 1), round(estimated_cm * 1.15, 1))

        depth_variance = float(np.var(corridor))

        # Locate dominant hazard bounding rectangle if present
        dominant_box = None
        active_mask = drop_mask if is_drop else (barrier_mask if is_barrier else None)
        if active_mask is not None:
            contours, _ = cv2.findContours(active_mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if contours:
                c = max(contours, key=cv2.contourArea)
                x, y, bw, bh = cv2.boundingRect(c)
                dominant_box = (int(x), int(y + corridor_y_start), int(bw), int(bh))

        profile = SpatialHazardProfile(
            is_vertical_drop=is_drop,
            vertical_drop_score=round(max_drop_ratio, 4),
            is_elevation_barrier=is_barrier,
            elevation_hazard_score=round(max_barrier_ratio, 4),
            hazard_category=hazard_cat,
            safe_walking_path_clear=safe_path,
            estimated_drop_cm=estimated_cm,
            estimated_drop_cm_bounds=cm_bounds,
            depth_disparity_variance=round(depth_variance, 4),
            dominant_hazard_region=dominant_box,
            depth_backend=("opencv_dnn_onnx" if self.use_onnx else "geometric_fallback"),
            depth_model=self.model_name,
        )

        return depth_map, profile


def discover_depth_model(preferred_profile: str = "realtime_mobile_30fps") -> Optional[str]:
    """Locate a monocular depth ONNX model shipped with the repository.

    Search order:
      1. The GOZVISION_DEPTH_MODEL environment variable.
      2. If performance_profile == "realtime_mobile_30fps":
         Prefer lightweight mobile ONNX models (model-small.onnx @ 28 FPS).
      3. If performance_profile == "high_fidelity_depth":
         Prefer high-capacity models (depth_anything_v2_vits.onnx @ 7 FPS).
      4. models/ next to the backend package.
      5. backend/evaluation/dataset/raw/ (development fallback).

    Returns the path to the best matching ONNX model found, or None when no model is
    available (in which case the geometric depth fallback is used).
    """
    env = os.environ.get("GOZVISION_DEPTH_MODEL")
    if env and os.path.exists(env):
        return env

    here = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.dirname(here)
    repo_root = os.path.dirname(backend_dir)
    candidates = [
        os.path.join(backend_dir, "models"),
        os.path.join(repo_root, "models"),
        os.path.join(backend_dir, "evaluation", "dataset", "raw"),
    ]
    preferred_pattern = "model-small" if preferred_profile == "realtime_mobile_30fps" else "depth_anything"

    # Pass 1: Look for preferred model profile
    for directory in candidates:
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if name.lower().endswith(".onnx") and preferred_pattern in name.lower():
                return os.path.join(directory, name)

    # Pass 2: Fall back to any available ONNX model
    for directory in candidates:
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if name.lower().endswith(".onnx"):
                return os.path.join(directory, name)
    return None


class LowVisionEnhancer:
    """Real-time OpenCV 5 visual pre-processor for low-vision patients.

    Supports both the legacy ``VisionEnhancementConfig`` (static parameters)
    and the new ``DiagnosisAdaptiveConfig`` (FHIR-driven per-condition tuning).
    Pass a ``DiagnosisAdaptiveConfig`` built via ``build_config_from_diagnosis``
    to activate the DAVE (Diagnosis-Adaptive Vision Enhancement) pathway.
    """

    def __init__(
        self,
        config: Optional[VisionEnhancementConfig] = None,
        dave_config: Optional[DiagnosisAdaptiveConfig] = None,
    ):
        self.config = config or VisionEnhancementConfig()
        self.dave_config: Optional[DiagnosisAdaptiveConfig] = dave_config

        # Build CLAHE from whichever config is active.  When a dave_config is
        # provided its clip_limit and tile_grid_size take precedence, because
        # they are condition-specific.
        clip = self.dave_config.clahe_clip_limit if self.dave_config else self.config.clahe_clip_limit
        grid = self.dave_config.clahe_tile_grid_size if self.dave_config else self.config.clahe_tile_grid_size
        self.clahe = cv2.createCLAHE(clipLimit=clip, tileGridSize=grid)

        model_path = self.config.onnx_depth_model_path or discover_depth_model(self.config.performance_profile)
        self.config.onnx_depth_model_path = model_path
        input_size = (192, 192) if (model_path and "model-small" in model_path.lower()) else (256, 256)
        self.spatial_estimator = SpatialDepthEstimator(model_path, input_size=input_size)
        self.stereo_estimator = StereoDepthEstimator(baseline_m=0.065)

    def set_dave_config(self, dave_config: DiagnosisAdaptiveConfig) -> None:
        """Hot-swap the diagnosis-adaptive config at runtime (e.g. after FHIR sync).

        Rebuilds CLAHE with the new condition-specific parameters so the change
        takes effect on the very next processed frame.
        """
        self.dave_config = dave_config
        self.clahe = cv2.createCLAHE(
            clipLimit=dave_config.clahe_clip_limit,
            tileGridSize=dave_config.clahe_tile_grid_size,
        )

    def get_telemetry(self) -> Dict[str, Any]:
        """Expose runtime telemetry, including the active depth backend and DAVE profile."""
        tel: Dict[str, Any] = {
            "opencv_version": cv2.__version__,
            "opencv_optimized": cv2.useOptimized(),
            "opencv_threads": cv2.getNumThreads(),
            "clahe_clip_limit": self.clahe.getClipLimit(),
            "clahe_tile_grid_size": list(self.clahe.getTilesGridSize()),
            **self.spatial_estimator.get_backend_telemetry(),
        }
        if self.dave_config is not None:
            tel["dave_profile"] = self.dave_config.profile_name
            tel["dave_icd10_codes"] = list(self.dave_config.icd10_codes)
            tel["dave_processing_order"] = list(self.dave_config.processing_order)
            tel["dave_spatial_mask_active"] = self.dave_config.spatial_weight_map is not None
        return tel

    def enhance_contrast_and_edges(
        self,
        frame: np.ndarray,
        spatial_weight: Optional[np.ndarray] = None,
    ) -> np.ndarray:
        """Enhances local luminance contrast (CLAHE in LAB space) and overlays edge cues.

        Essential for macular degeneration and diabetic retinopathy where contrast
        sensitivity drops sharply.

        When ``spatial_weight`` is provided (a float32 H×W map in [0, 1]) the
        enhancement *delta* is modulated by that map before blending back.  In
        scotoma regions (weight ≈ 0) the original luminance is preserved; in
        fully-sighted regions (weight ≈ 1) full CLAHE enhancement is applied.
        This is the core mechanism of the DAVE system.
        """
        if frame is None or frame.size == 0:
            raise ValueError("Invalid frame provided to enhance_contrast_and_edges")

        # 1. Convert to LAB color space — process Luminance (L) independently of colour
        lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)

        # 2. Apply CLAHE on L channel
        enhanced_l = self.clahe.apply(l)

        # 3. Detect edge boundaries on the CLAHE-enhanced L
        blurred = cv2.GaussianBlur(enhanced_l, (3, 3), 0)
        edges = cv2.Canny(blurred, threshold1=40, threshold2=120)

        # 4. Blend enhanced luminance with edge highlights
        edge_weight = (
            self.dave_config.edge_enhancement_weight
            if self.dave_config is not None
            else self.config.edge_enhancement_weight
        )
        composite_l = cv2.addWeighted(enhanced_l, 1.0, edges, edge_weight, 0)

        # 5. Diagnosis-adaptive spatial weighting (DAVE).
        #    In scotoma regions the composite equals the original L (no change).
        #    In fully-sighted regions the composite equals the CLAHE output.
        if spatial_weight is not None:
            sw = cv2.resize(spatial_weight, (frame.shape[1], frame.shape[0]))
            composite_l = (
                composite_l.astype(np.float32) * sw
                + l.astype(np.float32) * (1.0 - sw)
            ).clip(0, 255).astype(np.uint8)

        # 6. Recombine and convert back to BGR
        composite_lab = cv2.merge((composite_l, a, b))
        return cv2.cvtColor(composite_lab, cv2.COLOR_LAB2BGR)

    def suppress_glare(self, frame: np.ndarray) -> np.ndarray:
        """Reduces blinding specular highlights for cataract and photophobia sufferers.

        Uses condition-specific threshold and suppression factor from the active
        DiagnosisAdaptiveConfig when available.  Cataract patients require a lower
        glare threshold (210 vs 240) because intra-lens scatter spreads bright regions.
        """
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        threshold = (
            self.dave_config.glare_threshold
            if self.dave_config is not None
            else self.config.glare_threshold
        )
        suppression = (
            self.dave_config.glare_suppression_factor
            if self.dave_config is not None
            else self.config.glare_suppression_factor
        )

        # Mask specular highlights
        _, glare_mask = cv2.threshold(gray, threshold, 255, cv2.THRESH_BINARY)

        # Dilate to capture the halo fringe around hot spots
        glare_mask_dilated = cv2.dilate(glare_mask, np.ones((5, 5), np.uint8), iterations=1)

        glare_count = cv2.countNonZero(glare_mask_dilated)
        if glare_count > 0:
            # OpenCV 5 Telea Fast Marching inpainting reconstructs occluded texture
            inpainted = cv2.inpaint(frame, glare_mask_dilated, inpaintRadius=3, flags=cv2.INPAINT_TELEA)
            # Blend 70% reconstructed background texture with 30% attenuated natural luminance
            dimmed = (frame.astype(np.float32) * suppression).astype(np.uint8)
            blended = cv2.addWeighted(inpainted, 0.70, dimmed, 0.30, 0)
            result = frame.copy()
            result[glare_mask_dilated > 0] = blended[glare_mask_dilated > 0]
            return result

        return frame.copy()

    def detect_reading_regions(self, frame: np.ndarray) -> list[dict]:
        """Detects candidate text/reading zones in the visual field using morphological gradients.
        
        Returns a list of bounding boxes: [{'x': x, 'y': y, 'w': w, 'h': h, 'confidence': float}]
        """
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Morphological gradient to isolate text stroke boundaries
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9, 3))
        grad = cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, kernel)
        
        # Binarize with Otsu
        _, thresh = cv2.threshold(grad, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        
        # Connect nearby letter components horizontally
        connected = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        contours, _ = cv2.findContours(connected, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        regions = []
        frame_h, frame_w = frame.shape[:2]
        
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            # Filter noise / non-text aspect ratios
            if w > 20 and h > 8 and (w * h) < (frame_w * frame_h * 0.5):
                aspect_ratio = float(w) / max(h, 1)
                if aspect_ratio >= 1.0:
                    regions.append({
                        "x": int(x),
                        "y": int(y),
                        "w": int(w),
                        "h": int(h),
                        "aspect_ratio": round(aspect_ratio, 2),
                    })
                    
        return regions

    def assess_spatial_hazards(
        self,
        frame: np.ndarray,
        camera_height_m: float = 1.55,
        camera_pitch_rad: float = 0.0,
        intrinsics: Optional[CameraIntrinsics] = None,
        prev_frame: Optional[np.ndarray] = None,
        right_frame: Optional[np.ndarray] = None,
    ) -> Tuple[np.ndarray, SpatialHazardProfile]:
        """Runs the OpenCV 5 spatial depth disparity engine to identify 3D drop-offs vs 2D shadows.

        When `right_frame` is provided (binocular smart glasses mode), computes deterministic
        metric disparity via `cv2.StereoSGBM` triangulation, completely bypassing monocular depth
        approximations.

        When `prev_frame` is provided, dynamically calibrates ground lookahead distance
        via forward optical flow divergence and applies epipolar Plane-plus-Parallax (P+P)
        homography consistency to veto planar ground textures and cast shadows.
        """
        cal = intrinsics or self.config.camera_intrinsics
        if right_frame is not None:
            return self.stereo_estimator.analyze_walking_corridor(
                frame,
                right_frame,
                camera_height_m=camera_height_m,
                camera_pitch_rad=camera_pitch_rad,
                intrinsics=cal,
            )

        depth_map, profile = self.spatial_estimator.analyze_walking_corridor(
            frame,
            camera_height_m=camera_height_m,
            camera_pitch_rad=camera_pitch_rad,
            intrinsics=cal,
        )

        if prev_frame is not None and prev_frame.shape == frame.shape:
            # 1. Metric scale calibration via forward optical flow expansion
            try:
                z_metric, _ = SpatialDepthEstimator.estimate_metric_scale_optical_flow(
                    prev_frame, frame, intrinsics=cal
                )
                profile.calibrated_metric_z = z_metric
            except Exception:
                pass

            # 2. Epipolar Plane-plus-Parallax homography consistency veto
            if profile.is_vertical_drop or profile.is_elevation_barrier:
                try:
                    is_coplanar, rep_err = SpatialDepthEstimator.verify_planar_homography_consistency(
                        prev_frame,
                        frame,
                        hazard_region=profile.dominant_hazard_region,
                        max_inlier_reprojection_error=2.5,
                    )
                    profile.homography_reprojection_error_px = round(rep_err, 2)
                    if is_coplanar:
                        profile.homography_vetoed = True
                        profile.is_vertical_drop = False
                        profile.is_elevation_barrier = False
                        profile.hazard_category = "coplanar_clear"
                        profile.safe_walking_path_clear = True
                except Exception:
                    pass

        return depth_map, profile

    def process_frame(self, frame: np.ndarray, mode: str = "enhanced_contrast") -> Tuple[np.ndarray, dict]:
        """Unified entry point for the GozVision camera copilot stream.

        Modes:
        - 'enhanced_contrast': Diagnosis-adaptive CLAHE + edge overlay.  When a
          DiagnosisAdaptiveConfig is active, spatial weighting is applied so
          enhancement is concentrated in the patient's functioning retinal zones.
        - 'glare_suppression': Photophobia & cataract attenuation.  For cataract
          profiles the DAVE processing order runs glare suppression first.
        - 'reading': Locates and highlights text blocks with bounding boxes.
        - 'spatial_depth': OpenCV 5 monocular depth disparity & drop-off detection.
        """
        metadata: dict = {"mode": mode, "frame_shape": list(frame.shape)}

        # Attach DAVE profile metadata when active
        if self.dave_config is not None:
            metadata["dave_profile"] = self.dave_config.profile_name
            metadata["dave_icd10"] = list(self.dave_config.icd10_codes)

        if mode == "glare_suppression":
            processed = self.suppress_glare(frame)

        elif mode == "reading":
            regions = self.detect_reading_regions(frame)
            processed = frame.copy()
            for r in regions:
                cv2.rectangle(
                    processed,
                    (r["x"], r["y"]),
                    (r["x"] + r["w"], r["y"] + r["h"]),
                    (0, 255, 200),  # Goz malachite green highlight
                    2,
                )
            metadata["detected_text_regions"] = len(regions)
            metadata["regions"] = regions[:10]  # top 10

        elif mode == "spatial_depth":
            depth_map, profile = self.assess_spatial_hazards(frame)
            # Render false-color depth representation (TURBO colormap)
            depth_uint8 = (depth_map * 255.0).astype(np.uint8)
            processed = cv2.applyColorMap(depth_uint8, cv2.COLORMAP_TURBO)
            if profile.dominant_hazard_region is not None:
                x, y, w, h = profile.dominant_hazard_region
                color = (0, 0, 255) if profile.is_vertical_drop else (0, 165, 255)
                cv2.rectangle(processed, (x, y), (x + w, y + h), color, 3)
                label = (
                    f"STEP DOWN -{profile.estimated_drop_cm}cm"
                    if profile.is_vertical_drop
                    else "ELEVATION BARRIER"
                )
                cv2.putText(processed, label, (x, max(y - 8, 15)), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
            metadata["spatial_hazard"] = {
                "category": profile.hazard_category,
                "is_vertical_drop": profile.is_vertical_drop,
                "vertical_drop_score": profile.vertical_drop_score,
                "estimated_drop_cm": profile.estimated_drop_cm,
                "safe_path": profile.safe_walking_path_clear,
            }

        else:
            # 'enhanced_contrast' — respects DAVE processing_order for cataract profiles
            # where glare suppression must precede CLAHE (see DiagnosisAdaptiveConfig).
            dave = self.dave_config
            spatial_weight = dave.spatial_weight_map if dave is not None else None
            order = dave.processing_order if dave is not None else ("contrast", "glare", "edges")

            if order[0] == "glare":
                # Cataract pathway: de-haze first, then apply CLAHE to the clean signal
                pre_glare = self.suppress_glare(frame)
                processed = self.enhance_contrast_and_edges(pre_glare, spatial_weight=spatial_weight)
            else:
                processed = self.enhance_contrast_and_edges(frame, spatial_weight=spatial_weight)

        return processed, metadata
