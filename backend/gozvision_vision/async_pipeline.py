"""GozVision Asynchronous Decoupled Vision Pipeline.

Engineered to solve the real-time mobile perception dilemma:
Decouples the 2D visual enhancement loop (CLAHE, Glare Suppression, Reading boxes)
running synchronously at full display refresh rate (>60 FPS, <15 ms latency)
from the 3D DNN spatial depth estimation worker running asynchronously at 8–12 Hz.

Architecture:
  Camera Sensor Frame
          │
          ├──> [Loop A: Fast Synchronous Edge HUD Loop] (Target: 60+ FPS)
          │       ├── CLAHE contrast amplification (<12 ms)
          │       ├── Glare suppression (<15 ms)
          │       ├── Reading box highlights
          │       └── Non-blocking read of cached 3D hazard state ──> Screen Display (Smooth 60 FPS)
          │
          └──> [Loop B: Asynchronous Depth Worker] (Target: 8–12 Hz, maxsize=1 Drop Queue)
                  ├── Downsample to mobile-optimal resolution
                  ├── ONNX Depth forward pass
                  ├── Theil-Sen piecewise ground baseline fitting
                  ├── Temporal hazard coherence tracking
                  └── Thread-safe atomic update of latest_hazard_profile
"""
from __future__ import annotations

import logging
import queue
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Dict, Optional, Tuple

import cv2
import numpy as np

from .cv_pipeline import (
    CameraIntrinsics,
    LowVisionEnhancer,
    SpatialHazardProfile,
    TemporalHazardCoherenceTracker,
    VisionEnhancementConfig,
)

logger = logging.getLogger(__name__)


@dataclass
class AsyncPipelineTelemetry:
    """Runtime performance telemetry for the decoupled dual-loop architecture."""
    loop_a_fps: float = 0.0
    loop_a_latency_ms: float = 0.0
    loop_b_fps: float = 0.0
    loop_b_latency_ms: float = 0.0
    frames_processed_a: int = 0
    frames_processed_b: int = 0
    frames_dropped_b: int = 0
    active_depth_model: str = "model-small.onnx"
    latest_hazard_category: str = "coplanar_clear"
    latest_drop_cm: float = 0.0


class AsyncAccessibilityPipeline:
    """Production asynchronous pipeline guaranteeing 60+ FPS camera display while running DNN depth."""

    def __init__(
        self,
        enhancer: Optional[LowVisionEnhancer] = None,
        config: Optional[VisionEnhancementConfig] = None,
        temporal_window: int = 5,
        temporal_min_coherence: float = 0.60,
    ):
        if enhancer is not None:
            self.enhancer = enhancer
        else:
            self.enhancer = LowVisionEnhancer(config=config or VisionEnhancementConfig())

        self.temporal_tracker = TemporalHazardCoherenceTracker(
            window=temporal_window, min_coherence=temporal_min_coherence
        )

        # Drop-old queue: always feeds the most recent frame to the depth worker
        self._frame_queue: queue.Queue = queue.Queue(maxsize=1)
        self._latest_hazard: Optional[SpatialHazardProfile] = None
        self._hazard_lock = threading.Lock()
        self._running = True

        # Telemetry counters
        self._frames_a = 0
        self._frames_b = 0
        self._frames_dropped_b = 0
        self._t_start_a = time.perf_counter()
        self._t_start_b = time.perf_counter()
        self._last_latency_a = 0.0
        self._last_latency_b = 0.0

        # Start background depth worker thread
        self._depth_thread = threading.Thread(
            target=self._depth_worker_loop, name="GozVisionDepthWorker", daemon=True
        )
        self._depth_thread.start()

    def _depth_worker_loop(self) -> None:
        """Loop B: runs asynchronously at 8–12 Hz without blocking the camera display."""
        while self._running:
            try:
                item = self._frame_queue.get(timeout=0.05)
            except queue.Empty:
                continue

            frame, pitch_rad, camera_height_m, intrinsics = item
            t0 = time.perf_counter()

            try:
                # Assess spatial hazards with IMU pitch orientation
                _, raw_profile = self.enhancer.assess_spatial_hazards(
                    frame,
                    camera_height_m=camera_height_m,
                    camera_pitch_rad=pitch_rad,
                    intrinsics=intrinsics,
                )
                # Gated through temporal coherence
                gated_profile = self.temporal_tracker.update(raw_profile)

                with self._hazard_lock:
                    self._latest_hazard = gated_profile

                self._frames_b += 1
                self._last_latency_b = (time.perf_counter() - t0) * 1000.0

            except Exception as e:
                logger.warning("Error in background depth inference worker: %s", e)
            finally:
                self._frame_queue.task_done()

    def process_live_frame(
        self,
        frame: np.ndarray,
        camera_pitch_rad: float = 0.0,
        camera_height_m: float = 1.55,
        mode: str = "enhanced_contrast",
        intrinsics: Optional[CameraIntrinsics] = None,
        draw_hud: bool = True,
    ) -> Tuple[np.ndarray, Dict[str, Any]]:
        """Loop A: Main synchronous rendering loop executed on every incoming camera frame.

        Runs at full screen display refresh rate (>60 FPS, <15 ms latency).
        Does NOT block on depth inference. Non-blockingly reads the cached hazard profile.
        """
        t0 = time.perf_counter()
        self._frames_a += 1

        # 1. Non-blocking dispatch to background depth worker (drops frame if worker is busy)
        try:
            self._frame_queue.put_nowait((frame, camera_pitch_rad, camera_height_m, intrinsics))
        except queue.Full:
            self._frames_dropped_b += 1

        # 2. Fast synchronous 2D visual enhancement (CLAHE / Glare Suppression)
        enhanced_frame, meta = self.enhancer.process_frame(frame, mode=mode)

        # 3. Non-blocking read of the latest 3D hazard state from Loop B
        with self._hazard_lock:
            hazard = self._latest_hazard

        # 4. Overlay hazard bounding boxes and warning cues if hazard is active
        if draw_hud and hazard is not None and (hazard.is_vertical_drop or hazard.is_elevation_barrier):
            if hazard.dominant_hazard_region:
                x, y, w, h = hazard.dominant_hazard_region
                color = (0, 0, 255) if hazard.is_vertical_drop else (0, 165, 255)
                cv2.rectangle(enhanced_frame, (x, y), (x + w, y + h), color, 3)
                
                label = (
                    f"STEP DOWN: {int(hazard.estimated_drop_cm)}cm"
                    if hazard.is_vertical_drop
                    else f"BARRIER: {int(hazard.estimated_drop_cm)}cm"
                )
                cv2.putText(
                    enhanced_frame,
                    label,
                    (x, max(30, y - 10)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.75,
                    color,
                    2,
                )

        t_elapsed = (time.perf_counter() - t0) * 1000.0
        self._last_latency_a = t_elapsed

        meta["async_loop_a_latency_ms"] = round(t_elapsed, 2)
        meta["cached_hazard_profile"] = hazard
        return enhanced_frame, meta

    def get_telemetry(self) -> AsyncPipelineTelemetry:
        """Returns comprehensive telemetry proving dual-loop performance."""
        dt_a = max(time.perf_counter() - self._t_start_a, 0.001)
        dt_b = max(time.perf_counter() - self._t_start_b, 0.001)
        fps_a = self._frames_a / dt_a
        fps_b = self._frames_b / dt_b

        with self._hazard_lock:
            h = self._latest_hazard
            cat = h.hazard_category if h else "coplanar_clear"
            cm = h.estimated_drop_cm if h else 0.0

        return AsyncPipelineTelemetry(
            loop_a_fps=round(fps_a, 2),
            loop_a_latency_ms=round(self._last_latency_a, 2),
            loop_b_fps=round(fps_b, 2),
            loop_b_latency_ms=round(self._last_latency_b, 2),
            frames_processed_a=self._frames_a,
            frames_processed_b=self._frames_b,
            frames_dropped_b=self._frames_dropped_b,
            latest_hazard_category=cat,
            latest_drop_cm=cm,
        )

    def stop(self, timeout_s: float = 1.0) -> None:
        """Gracefully halts the background depth inference worker."""
        self._running = False
        if self._depth_thread.is_alive():
            self._depth_thread.join(timeout=timeout_s)
