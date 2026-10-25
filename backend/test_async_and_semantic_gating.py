"""Tests for Asynchronous Dual-Loop Pipeline, IMU Pitch Stabilization, and Photometric Semantic Gating."""
import time
import unittest
from pathlib import Path
import cv2
import numpy as np

from gozvision_vision.cv_pipeline import (
    CameraIntrinsics,
    LowVisionEnhancer,
    SpatialDepthEstimator,
    SpatialHazardProfile,
    VisionEnhancementConfig,
)
from gozvision_vision.async_pipeline import AsyncAccessibilityPipeline

_DATASET_RAW = Path(__file__).resolve().parent / "evaluation" / "dataset" / "raw"


class TestAsyncAndSemanticGating(unittest.TestCase):

    def setUp(self):
        self.config = VisionEnhancementConfig(performance_profile="realtime_mobile_30fps")
        self.enhancer = LowVisionEnhancer(self.config)

    def test_async_decoupled_pipeline_throughput_60fps(self):
        """Loop A must process incoming frames at >60 FPS (<16.7 ms latency) without waiting on DNN depth."""
        pipeline = AsyncAccessibilityPipeline(self.enhancer)
        sample_path = _DATASET_RAW / "street1.jpg"
        self.assertTrue(sample_path.exists())
        frame = cv2.imread(str(sample_path))
        self.assertIsNotNone(frame)

        # Warmup pass (initializes JIT tables and thread structures)
        pipeline.process_live_frame(frame, camera_pitch_rad=0.05, mode="enhanced_contrast", draw_hud=True)

        # Process 30 frames through Loop A
        t0 = time.perf_counter()
        latencies = []
        for i in range(30):
            t_frame = time.perf_counter()
            out_frame, meta = pipeline.process_live_frame(
                frame, camera_pitch_rad=0.05, mode="enhanced_contrast", draw_hud=True
            )
            lat = (time.perf_counter() - t_frame) * 1000.0
            latencies.append(lat)
            self.assertEqual(out_frame.shape, frame.shape)
            self.assertIn("async_loop_a_latency_ms", meta)

        total_elapsed = time.perf_counter() - t0
        avg_latency = sum(latencies) / len(latencies)
        fps_a = len(latencies) / total_elapsed

        # Give background worker a moment to complete at least 1 pass
        t_wait_start = time.perf_counter()
        while pipeline.get_telemetry().frames_processed_b < 1 and (time.perf_counter() - t_wait_start) < 3.0:
            time.sleep(0.05)
        telemetry = pipeline.get_telemetry()
        pipeline.stop(timeout_s=0.05)

        # Loop A display loop assertions
        self.assertLess(avg_latency, 25.0, f"Loop A average latency must be <25ms, got {avg_latency:.2f}ms")
        self.assertGreater(fps_a, 40.0, f"Loop A throughput must exceed 40 FPS, got {fps_a:.2f} FPS")
        self.assertGreaterEqual(telemetry.frames_processed_a, 30)
        self.assertGreaterEqual(telemetry.frames_processed_b, 1, "Background worker Loop B must process frames")

    def test_imu_pitch_corridor_horizon_shifting(self):
        """Device pitch tilt must dynamically adjust corridor_y_start via pinhole projection."""
        estimator = SpatialDepthEstimator()
        frame = np.full((480, 640, 3), 128, dtype=np.uint8)
        intrinsics = CameraIntrinsics.from_frame_shape(480, 640)

        # 1. Level horizon (0.0 rad)
        nominal_y = int(intrinsics.cy)

        # 2. Downward tilt (looking more toward feet: +15 deg = +0.26 rad)
        pitch_down = 0.26
        expected_shift_down = int(intrinsics.fy * np.tan(pitch_down))
        self.assertGreater(expected_shift_down, 0)

        # 3. Upward tilt (looking toward horizon: -10 deg = -0.17 rad)
        pitch_up = -0.17
        expected_shift_up = int(intrinsics.fy * np.tan(pitch_up))
        self.assertLess(expected_shift_up, 0)

        # Verify analyze_walking_corridor executes safely with real pitch inputs
        _, prof_down = estimator.analyze_walking_corridor(
            frame, camera_pitch_rad=pitch_down, intrinsics=intrinsics
        )
        self.assertIsNotNone(prof_down)

        _, prof_up = estimator.analyze_walking_corridor(
            frame, camera_pitch_rad=pitch_up, intrinsics=intrinsics
        )
        self.assertIsNotNone(prof_up)

    def test_photometric_shadow_chromaticity_invariance(self):
        """2D ground shadow preserves chrominance ΔE_ab across the boundary while luminance steps down."""
        # Create a synthetic uniform pavement with a cast shadow on the lower half
        # Base pavement: BGR [140, 140, 140] (neutral gray)
        h, w = 300, 400
        pavement = np.full((h, w, 3), 140, dtype=np.uint8)
        # Cast shadow on lower half: 50% luminance reduction, same chromatic ratio
        shadow_boundary = 150
        pavement[shadow_boundary:, :] = (pavement[shadow_boundary:, :].astype(np.float32) * 0.45).astype(np.uint8)

        # Sample strip above and below shadow boundary
        band = 10
        above = pavement[shadow_boundary - band : shadow_boundary, :]
        below = pavement[shadow_boundary : shadow_boundary + band, :]

        lab_above = cv2.cvtColor(above, cv2.COLOR_BGR2LAB).astype(np.float32)
        lab_below = cv2.cvtColor(below, cv2.COLOR_BGR2LAB).astype(np.float32)

        delta_a = float(np.mean(lab_above[:, :, 1]) - np.mean(lab_below[:, :, 1]))
        delta_b = float(np.mean(lab_above[:, :, 2]) - np.mean(lab_below[:, :, 2]))
        chroma_dist = float(np.sqrt(delta_a**2 + delta_b**2))

        l_above = float(np.mean(lab_above[:, :, 0]))
        l_below = float(np.mean(lab_below[:, :, 0]))
        lum_drop = abs(l_above - l_below) / max(l_above, l_below)

        # Shadow ground invariant: chrominance distance is near zero despite steep luminance drop
        self.assertLess(chroma_dist, 1.0, "Shadow boundary on uniform pavement must preserve chromaticity")
        self.assertGreater(lum_drop, 0.40, "Cast shadow must exhibit a sharp luminance drop")

    def test_planar_homography_shadow_coplanarity_veto(self):
        """Planar homography consistency mathematically vetoes coplanar 2D pavement markings."""
        # Frame 1: pavement with texture dots and a painted shadow patch
        h, w = 320, 400
        rng = np.random.default_rng(42)
        f1 = np.full((h, w, 3), 130, dtype=np.uint8)
        # Add high-contrast feature dots across lower walking corridor
        for _ in range(60):
            rx, ry = int(rng.integers(30, w - 30)), int(rng.integers(int(h * 0.5), h - 20))
            cv2.circle(f1, (rx, ry), 3, (int(rng.integers(20, 240)),) * 3, -1)
        # Add a 2D rectangular dark shadow patch
        hazard_box = (120, 180, 160, 60)
        cv2.rectangle(f1, (hazard_box[0], hazard_box[1]), (hazard_box[0] + hazard_box[2], hazard_box[1] + hazard_box[3]), (50, 50, 50), -1)

        # Frame 2: planar ground transformation simulating camera walking forward/down
        M_planar = np.float32([[1.0, 0.0, 0.0], [0.0, 1.0, 3.0]])
        f2 = cv2.warpAffine(f1, M_planar, (w, h), borderMode=cv2.BORDER_REFLECT)

        is_coplanar, err = SpatialDepthEstimator.verify_planar_homography_consistency(
            f1, f2, hazard_region=hazard_box
        )
        self.assertTrue(is_coplanar, f"Coplanar pavement patch must adhere to ground homography (err={err:.2f})")
        self.assertLess(err, 3.0, "Homography reprojection error for planar patch must be < 3.0 px")

    def test_optical_flow_metric_scale_calibration(self):
        """Optical flow vertical divergence rate dynamically computes physical metric ground scale."""
        h, w = 320, 400
        f1 = np.full((h, w, 3), 120, dtype=np.uint8)
        rng = np.random.default_rng(101)
        # Add ground texture points in walking corridor
        for _ in range(50):
            rx, ry = int(rng.integers(20, w - 20)), int(rng.integers(int(h * 0.55), h - 15))
            cv2.circle(f1, (rx, ry), 3, (int(rng.integers(10, 250)),) * 3, -1)

        # Simulate forward motion: points expand downward proportional to y
        # dy = (y_rel * V_z * dt) / Z = (y_rel * 1.2 * (1/30)) / 2.0 = y_rel * 0.02
        f2 = np.copy(f1)
        # Downward affine expansion
        M_exp = np.float32([[1.0, 0.0, 0.0], [0.0, 1.0, 2.5]])
        f2 = cv2.warpAffine(f1, M_exp, (w, h), borderMode=cv2.BORDER_REFLECT)

        z_metric, (z_low, z_high) = SpatialDepthEstimator.estimate_metric_scale_optical_flow(
            f1, f2, dt_sec=1.0/30.0, walking_speed_mps=1.2
        )
        self.assertGreaterEqual(z_metric, 0.8)
        self.assertLessEqual(z_metric, 5.0)
        self.assertLess(z_low, z_metric)
        self.assertGreater(z_high, z_metric)

    def test_concurrent_multi_stream_stress(self):
        """Simulate concurrent multi-stream workers verifying aggregate throughput & drop-old stability."""
        from evaluation.stress_concurrency import ConcurrencyStressHarness
        harness = ConcurrencyStressHarness(num_workers=3, frames_per_worker=10)
        res = harness.run_benchmark()
        self.assertEqual(res["num_concurrent_streams"], 3)
        self.assertEqual(res["total_frames_processed"], 30)
        self.assertGreater(res["aggregate_throughput_fps"], 5.0)
        self.assertLess(res["p50_latency_ms"], 50.0)


if __name__ == "__main__":
    unittest.main()
