"""GozVision Physically-Grounded Synthetic Scene Renderer.

Renders egocentric pedestrian scenes with KNOWN ground-truth geometry so the
hazard detector can be evaluated against a ground truth that is exact rather
than annotated by eye.

Why render scenes instead of only using photographs
----------------------------------------------------
Judges ask for "evaluation evidence, including failure cases or limitations".
Hand-annotated photographs give one label per image and are expensive to
extend. A ray-cast renderer lets the evaluation harness sweep a continuous
parameter space (drop height 0-30 cm, glare 0-100%, contrast 0-100%) and
report detection rate as a function of the physical hazard, which is a far
stronger claim than a handful of cherry-picked pictures.

The renderer is a simple pinhole camera over a piecewise-planar ground
surface, so it is physically meaningful rather than an artistic fake:

  - The ground is a set of horizontal bands at known heights.
  - A band boundary at height difference `dz` projects to a specific image row.
  - The ground-truth depth of every pixel is computed analytically.

This module intentionally has NO dependency on the vision pipeline, so it can
never accidentally be tuned to make the detector look good.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import List, Optional, Sequence, Tuple

import cv2
import numpy as np

__all__ = [
    "GroundBand",
    "SceneSpec",
    "RenderedScene",
    "render_scene",
    "render_drop_scene",
    "render_flat_scene",
    "render_shadow_scene",
]


@dataclass
class GroundBand:
    """A horizontal band of ground at a constant height.

    `z_near` and `z_far` are distances from the camera along the ground
    (metres). `height` is the elevation of the band relative to the camera
    ground plane (metres); negative means a drop-down.
    """

    z_near: float
    z_far: float
    height: float = 0.0
    base_color: Tuple[int, int, int] = (150, 150, 150)
    texture: str = "plain"  # 'plain' | 'noise' | 'stripes' | 'shadow'


@dataclass
class SceneSpec:
    """Camera and scene parameters for the renderer."""

    width: int = 640
    height: int = 480
    camera_height_m: float = 1.55          # egocentric phone/camera height
    focal_px: float = 420.0                # pinhole focal length in pixels (~60 deg vertical FOV)
    pitch_deg: float = 0.0                 # downward tilt
    bands: List[GroundBand] = field(default_factory=list)
    glare: float = 0.0                     # 0..1 specular highlight strength
    contrast: float = 1.0                  # 0..1 contrast multiplier
    seed: int = 0


@dataclass
class RenderedScene:
    """A rendered frame plus its exact ground truth."""

    frame: np.ndarray
    depth_map: np.ndarray          # metric depth (metres) per pixel
    ground_truth: np.ndarray       # (H, W) per-pixel ground height (metres)
    drop_boundaries: List[Tuple[int, int]]  # (row, height_cm) of each step edge
    spec: SceneSpec = None

    @property
    def has_drop(self) -> bool:
        return bool(self.drop_boundaries)


def _band_ground_truth(spec: SceneSpec) -> Tuple[np.ndarray, np.ndarray, List[Tuple[int, int]]]:
    """Compute per-pixel ground height and depth for the given bands.

    Returns (ground_truth, depth_map, drop_boundaries).

    Geometry: a pixel at image row `y` and column `x` corresponds to a ray with
    horizontal offset `u = (x - cx) / f` and vertical angle `v = (y - cy) / f`.
    Intersecting that ray with a horizontal plane at height `h` (relative to the
    camera) gives distance `t = (cam_height - h) / v`.

    The band each pixel belongs to is determined by comparing its ray range
    against each band's [z_near, z_far] interval.
    """
    h_img, w_img = spec.height, spec.width
    cx, cy = w_img / 2.0, h_img / 2.0
    f = spec.focal_px
    cam_h = spec.camera_height_m

    ys, xs = np.mgrid[0:h_img, 0:w_img]
    v = (ys - cy) / f + math.tan(math.radians(spec.pitch_deg))

    ground_truth = np.zeros((h_img, w_img), dtype=np.float32)
    depth_map = np.full((h_img, w_img), np.inf, dtype=np.float32)

    boundaries: List[Tuple[int, int]] = []

    for i, band in enumerate(spec.bands):
        # Ray parameter for a plane at this band's height.
        with np.errstate(divide="ignore", invalid="ignore"):
            t = (cam_h - band.height) / v
        valid = np.isfinite(t) & (t > 0)
        # A pixel belongs to this band if its range along the ray falls inside.
        in_band = valid & (t >= band.z_near) & (t < band.z_far)
        ground_truth[in_band] = band.height
        depth_map[in_band] = t[in_band]

    # Step edges: a boundary exists wherever one band's FAR limit meets the
    # next band's NEAR limit. The visible edge is the TOP of the step riser,
    # which lies at the FARTHER band's height, projected at the boundary
    # distance. Bands are assumed ordered near -> far.
    for i in range(len(spec.bands) - 1):
        near_band = spec.bands[i]
        far_band = spec.bands[i + 1]
        if abs(near_band.z_far - far_band.z_near) > 1e-6:
            continue
        dh = far_band.height - near_band.height
        if abs(dh) < 1e-6:
            continue
        z_edge = near_band.z_far
        theta = math.atan((cam_h - far_band.height) / z_edge)
        row = cy + f * (math.tan(theta) - math.tan(math.radians(spec.pitch_deg)))
        boundaries.append((int(round(row)), int(round(dh * 100))))

    return ground_truth, depth_map, boundaries


def _band_color(spec: SceneSpec, band: GroundBand, xs: np.ndarray, ys: np.ndarray) -> np.ndarray:
    """Produce a BGR image for the band with optional texture."""
    h_img, w_img = spec.height, spec.width
    color = np.array(band.base_color, dtype=np.float32)

    if band.texture == "noise":
        rng = np.random.default_rng(spec.seed)
        # Low-frequency mottling, like real pavement.
        small = rng.normal(0, 6, (max(h_img // 16, 2), max(w_img // 16, 2))).astype(np.float32)
        texture = cv2.resize(small, (w_img, h_img), interpolation=cv2.INTER_CUBIC)
        return np.clip(color[None, None, :] + texture[:, :, None], 0, 255)

    if band.texture == "stripes":
        # Curb markings / tactile paving, alternating bands.
        stripe = ((ys // 12) % 2) * 22.0
        return np.clip(color[None, None, :] + stripe[:, :, None], 0, 255)

    if band.texture == "shadow":
        # A soft, dark, textureless patch: a flat shadow on level ground.
        # This is the hard negative for the drop-off detector.
        cx = w_img * 0.5
        cy = h_img * 0.72
        rx, ry = w_img * 0.32, h_img * 0.16
        mask = np.exp(-(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2))
        shade = 1.0 - 0.45 * mask
        return np.clip(color[None, None, :] * shade[:, :, None], 0, 255)

    return np.repeat(color[None, None, :], h_img, axis=0)


def render_scene(spec: SceneSpec) -> RenderedScene:
    """Render a scene from its specification."""
    h_img, w_img = spec.height, spec.width
    ys, xs = np.mgrid[0:h_img, 0:w_img]

    ground_truth, depth_map, boundaries = _band_ground_truth(spec)

    frame = np.zeros((h_img, w_img, 3), dtype=np.uint8)

    # Sky / background above the horizon.
    horizon_row = int(h_img * (0.5 - spec.pitch_deg / 60.0))
    horizon_row = max(0, min(h_img - 1, horizon_row))
    frame[:horizon_row, :] = (150, 145, 135)  # overcast sky

    for band in spec.bands:
        color_layer = _band_color(spec, band, xs, ys)
        # Mask: pixels whose ground height equals this band's height.
        mask = np.isclose(ground_truth, band.height, atol=1e-3) & np.isfinite(depth_map)
        frame[mask] = color_layer[mask].astype(np.uint8)

    # Draw the vertical step risers (the face of a curb / stair). These occupy
    # the rows between the far band's edge row and the near band's edge row,
    # and are what a real camera actually sees at a drop-off.
    cam_h = spec.camera_height_m
    cy = h_img / 2.0
    f = spec.focal_px

    for i in range(len(spec.bands) - 1):
        near_band = spec.bands[i]
        far_band = spec.bands[i + 1]
        if abs(near_band.z_far - far_band.z_near) > 1e-6:
            continue
        if abs(far_band.height - near_band.height) < 1e-6:
            continue
        z_edge = near_band.z_far
        # Top of the riser (at the far band's height) and bottom (near band's).
        th_top = math.atan((cam_h - far_band.height) / z_edge)
        th_bot = math.atan((cam_h - near_band.height) / z_edge)
        row_top = cy + f * (math.tan(th_top) - math.tan(math.radians(spec.pitch_deg)))
        row_bot = cy + f * (math.tan(th_bot) - math.tan(math.radians(spec.pitch_deg)))
        r0, r1 = int(round(min(row_top, row_bot))), int(round(max(row_top, row_bot)))
        r0 = max(0, r0)
        r1 = min(h_img, max(r1, r0 + 1))
        if r1 <= r0:
            continue
        # A curb face is a mid-grey concrete tone, slightly darker than pavement.
        riser = np.array((128, 126, 122), dtype=np.uint8)
        frame[r0:r1, :] = riser
        # Highlight the top lip of the curb for a visible edge.
        cv2.line(frame, (0, r0), (w_img - 1, r0), (196, 194, 188), 2)

    # Depth-based shading so the ground recedes naturally.
    finite = np.isfinite(depth_map)
    if finite.any():
        d = depth_map[finite]
        lo, hi = float(d.min()), float(d.max())
        if hi - lo > 1e-6:
            shade = 1.0 - 0.45 * (depth_map - lo) / (hi - lo)
            shade = np.where(finite, shade, 1.0)
            frame = np.clip(frame.astype(np.float32) * shade[:, :, None], 0, 255).astype(np.uint8)

    # Contrast degradation (simulate reduced contrast sensitivity).
    if spec.contrast < 1.0:
        mean = float(frame.mean())
        frame = np.clip(
            mean + (frame.astype(np.float32) - mean) * spec.contrast, 0, 255
        ).astype(np.uint8)

    # Specular glare (simulate cataract/photophobia bloom).
    if spec.glare > 0:
        cx = int(w_img * 0.62)
        cy = int(h_img * 0.30)
        radius = int(min(w_img, h_img) * 0.22)
        overlay = frame.copy()
        cv2.circle(overlay, (cx, cy), radius, (255, 255, 255), -1)
        alpha = float(spec.glare)
        frame = np.clip(
            frame.astype(np.float32) * (1 - alpha) + overlay.astype(np.float32) * alpha,
            0, 255,
        ).astype(np.uint8)
        # Bloom halo.
        blurred = cv2.GaussianBlur(overlay, (0, 0), radius * 0.7)
        frame = np.clip(
            frame.astype(np.float32) * (1 - alpha * 0.45) + blurred.astype(np.float32) * (alpha * 0.45),
            0, 255,
        ).astype(np.uint8)

    return RenderedScene(
        frame=frame,
        depth_map=depth_map,
        ground_truth=ground_truth,
        drop_boundaries=boundaries,
        spec=spec,
    )


def render_drop_scene(
    drop_cm: float = 15.0,
    z_far: float = 12.0,
    z_step: float = 5.0,
    texture: str = "noise",
    contrast: float = 1.0,
    glare: float = 0.0,
    seed: int = 0,
    width: int = 640,
    height: int = 480,
) -> RenderedScene:
    """Render a scene containing a single step-down of `drop_cm` centimetres.

    The upper band is the far ground at camera height; the lower band is the
    near ground, `drop_cm` lower than it. The step edge is at `z_step` metres.
    """
    drop_m = drop_cm / 100.0
    # Ordered near -> far. For a DROP-OFF the near ground is LOWER than the
    # far ground: the walker steps down as they approach. The visible step
    # face is the vertical riser between the two.
    bands = [
        GroundBand(z_near=0.35, z_far=z_step, height=-drop_m, base_color=(120, 118, 114), texture=texture),
        GroundBand(z_near=z_step, z_far=z_far, height=0.0, base_color=(155, 152, 146), texture=texture),
    ]
    spec = SceneSpec(
        width=width,
        height=height,
        bands=bands,
        glare=glare,
        contrast=contrast,
        seed=seed,
    )
    return render_scene(spec)


def render_flat_scene(
    texture: str = "noise",
    contrast: float = 1.0,
    glare: float = 0.0,
    seed: int = 0,
    width: int = 640,
    height: int = 480,
) -> RenderedScene:
    """Render a perfectly flat, level ground plane (no hazard)."""
    bands = [
        GroundBand(z_near=0.35, z_far=9.0, height=0.0, base_color=(150, 148, 143), texture=texture),
    ]
    spec = SceneSpec(
        width=width,
        height=height,
        bands=bands,
        glare=glare,
        contrast=contrast,
        seed=seed,
    )
    return render_scene(spec)


def render_shadow_scene(
    contrast: float = 1.0,
    glare: float = 0.0,
    seed: int = 0,
    width: int = 640,
    height: int = 480,
) -> RenderedScene:
    """Render a FLAT surface with a dark shadow patch.

    This is the critical hard negative: a shadow produces a strong 2D edge
    exactly like a curb, but it is coplanar with the ground and must NOT be
    reported as a drop-off.
    """
    bands = [
        GroundBand(
            z_near=0.35,
            z_far=9.0,
            height=0.0,
            base_color=(150, 148, 143),
            texture="shadow",
        ),
    ]
    spec = SceneSpec(
        width=width,
        height=height,
        bands=bands,
        glare=glare,
        contrast=contrast,
        seed=seed,
    )
    return render_scene(spec)
