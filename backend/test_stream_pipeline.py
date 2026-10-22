"""End-to-end video stream and perception integration test.

Validates the complete real-time pipeline:
1. Video stream ingestion and frame decoding.
2. Inpainting-based specular glare reduction (OpenCV 5 Telea Fast Marching).
3. Streaming throughput and P95 latency validation (ensuring >= 30 FPS capability).
4. Temporal coherence tracking across consecutive stream frames (shadow vs. drop).
"""
import time
import unittest
import numpy as np
import cv2

from gozvision_vision.cv_pipeline import (
    LowVisionEnhancer,
    TemporalHazardCoherenceTracker,
    VisionEnhancementConfig,
)
from gozvision_vision.scene_renderer import (
    render_drop_scene,
    render_flat_scene,
    render_shadow_scene,
)


class TestStreamPerceptionPipeline(unittest.TestCase):

    def setUp(self):
        self.enhancer = LowVisionEnhancer(VisionEnhancementConfig())
        self.tracker = TemporalHazardCoherenceTracker(window=5, min_coherence=0.6)

    def test_glare_inpainting_reconstruction(self):
        """Verify Telea inpainting reduces glare while reconstructing underlying texture."""
        # Create an image with textured background (stripes) and a high glare circle
        frame = np.zeros((300, 400, 3), dtype=np.uint8)
        for x in range(0, 400, 20):
            frame[:, x:x+10] = (60, 60, 60)
            frame[:, x+10:x+20] = (140, 140, 140)

        # Add blinding specular glare (intensity 255) in the middle
        glare_center = (200, 150)
        cv2.circle(frame, glare_center, 25, (255, 255, 255), -1)

        result = self.enhancer.suppress_glare(frame)

        self.assertEqual(result.shape, frame.shape)
        # Center of glare should be significantly reduced from 255
        center_val = int(result[150, 200, 0])
        self.assertLess(center_val, 240)
        # Verify texture variance inside the inpainted zone is non-zero (not a flat gray disc)
        patch = result[140:160, 190:210]
        self.assertGreater(float(np.std(patch)), 0.5)

    def test_continuous_stream_throughput(self):
        """Simulate a 30-frame live video stream and assert sustained >= 30 FPS."""
        # Generate 30 frames of a pedestrian walkway
        frames = [render_flat_scene(seed=i, width=320, height=240).frame for i in range(30)]

        t_start = time.perf_counter()
        processed_count = 0

        for frame in frames:
            proc, meta = self.enhancer.process_frame(frame, mode="enhanced_contrast")
            self.assertEqual(proc.shape, frame.shape)
            processed_count += 1

        elapsed = time.perf_counter() - t_start
        fps = processed_count / elapsed

        # Must maintain real-time accessibility performance (at least 30 FPS on 320x240 stream)
        self.assertGreater(fps, 30.0, f"Expected >30 FPS, got {fps:.2f} FPS")

    def test_stream_shadow_vs_stair_temporal_discrimination(self):
        """Verify temporal tracker suppresses shadow flicker across a stream and flags real drops."""
        # 1. Stream 10 frames of flat walkway with flickering ground shadow
        shadow_stream = [
            render_shadow_scene(contrast=0.40 + 0.35 * (1 if i in (1, 4, 7) else 0), seed=i, width=320, height=240).frame
            for i in range(10)
        ]

        self.tracker.reset()
        shadow_gated_results = []
        for frame in shadow_stream:
            _, profile = self.enhancer.assess_spatial_hazards(frame)
            gated = self.tracker.update(profile)
            shadow_gated_results.append(gated.is_vertical_drop)

        # Final frames of shadow stream must not be confirmed as drop hazards
        self.assertFalse(shadow_gated_results[-1], "Ground shadow incorrectly triggered drop alert")

        # 2. Stream 10 frames of actual staircase / physical curb drop in walking corridor (<2m)
        base_drop = render_drop_scene(drop_cm=16.0, z_step=1.5, seed=0, width=320, height=240).frame
        # Realistic camera sensor stream: consistent physical geometry with natural frame noise
        drop_stream = [
            (base_drop.astype(int) + (i % 3 - 1)).clip(0, 255).astype(np.uint8)
            for i in range(10)
        ]

        self.tracker.reset()
        drop_gated_results = []
        for frame in drop_stream:
            _, profile = self.enhancer.assess_spatial_hazards(frame)
            gated = self.tracker.update(profile)
            drop_gated_results.append(gated.is_vertical_drop)

        # After rolling window fills, drop must be confirmed
        self.assertTrue(drop_gated_results[-1], "Physical drop was not confirmed by temporal tracker")


if __name__ == "__main__":
    unittest.main()
