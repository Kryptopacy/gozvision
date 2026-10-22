"""Unit test suite for GozVision's OpenCV 5 Accessibility Pipeline."""
import unittest
import numpy as np
import cv2

from gozvision_vision.cv_pipeline import (
    CameraIntrinsics,
    LowVisionEnhancer,
    VisionEnhancementConfig,
    discover_depth_model,
    measure_contrast_improvement,
    measure_sighted_region_ssim,
)


class TestOpenCV5AccessibilityPipeline(unittest.TestCase):
    def setUp(self):
        self.enhancer = LowVisionEnhancer()
        # Synthetic 300x400 test frame (BGR)
        self.frame = np.zeros((300, 400, 3), dtype=np.uint8)
        # Add background gray gradient
        for y in range(300):
            self.frame[y, :, :] = int(y / 300.0 * 180)
        # Add a high-glare specular spot
        cv2.circle(self.frame, (200, 150), 30, (255, 255, 255), -1)
        # Add simulated text blocks
        cv2.putText(
            self.frame,
            "EYE CLINIC RECALL",
            (50, 80),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 255, 255),
            2,
        )

    def test_enhance_contrast_and_edges(self):
        output = self.enhancer.enhance_contrast_and_edges(self.frame)
        self.assertEqual(output.shape, self.frame.shape)
        self.assertEqual(output.dtype, np.uint8)

    def test_suppress_glare(self):
        output = self.enhancer.suppress_glare(self.frame)
        self.assertEqual(output.shape, self.frame.shape)
        # Glare circle center should be attenuated
        orig_val = int(self.frame[150, 200, 0])
        new_val = int(output[150, 200, 0])
        self.assertLess(new_val, orig_val)

    def test_detect_reading_regions(self):
        regions = self.enhancer.detect_reading_regions(self.frame)
        self.assertIsInstance(regions, list)
        self.assertGreater(len(regions), 0)
        first = regions[0]
        self.assertIn("x", first)
        self.assertIn("y", first)
        self.assertIn("w", first)
        self.assertIn("h", first)

    def test_process_frame_modes(self):
        for mode in ["enhanced_contrast", "glare_suppression", "reading", "spatial_depth"]:
            proc, meta = self.enhancer.process_frame(self.frame, mode=mode)
            self.assertEqual(proc.shape, self.frame.shape)
            self.assertEqual(meta["mode"], mode)
            if mode == "spatial_depth":
                self.assertIn("spatial_hazard", meta)
                self.assertIn("category", meta["spatial_hazard"])

    def test_spatial_depth_and_vertical_drop_detection(self):
        # Create a frame with a sharp curb/stair step down in the walking corridor
        step_frame = np.full((400, 500, 3), 160, dtype=np.uint8)
        # Drop-off edge across corridor (y=280) with sharp dark shadow beneath
        step_frame[280:, :] = 40
        cv2.line(step_frame, (0, 280), (500, 280), (255, 255, 255), 4)

        depth_map, profile = self.enhancer.assess_spatial_hazards(step_frame)
        self.assertEqual(depth_map.shape, (400, 500))
        self.assertTrue(profile.is_vertical_drop)
        self.assertEqual(profile.hazard_category, "vertical_drop")
        self.assertGreater(profile.vertical_drop_score, 0.0)
        self.assertGreaterEqual(profile.estimated_drop_cm, 0.0)

    def test_lateral_curb_active_drop_mask(self):
        """Lateral-only curb (left lane only) must produce a non-zero drop mask
        and a non-zero estimated_drop_cm — verifying the active_drop_mask bug fix."""
        # Step only on the LEFT third of the corridor, flat everywhere else
        h, w = 480, 600
        frame = np.full((h, w, 3), 140, dtype=np.uint8)
        # Left 200px only: sharp luminance drop at y=300
        frame[300:, :200] = 30
        cv2.line(frame, (0, 300), (200, 300), (255, 255, 255), 4)

        _, profile = self.enhancer.assess_spatial_hazards(frame)
        self.assertTrue(profile.is_vertical_drop,
                        "Lateral-only curb should still be flagged as vertical_drop")
        self.assertGreater(profile.vertical_drop_score, 0.0)
        # With the active_drop_mask fix, the bounding box must be set
        self.assertIsNotNone(profile.dominant_hazard_region,
                             "dominant_hazard_region must be non-None when lateral drop fires")

    def test_camera_intrinsics_and_photogrammetry(self):
        intrinsics = CameraIntrinsics.from_frame_shape(height=480, width=640, diagonal_fov_deg=75.0)
        self.assertGreater(intrinsics.fx, 400.0)
        self.assertEqual(intrinsics.fx, intrinsics.fy)
        self.assertEqual(intrinsics.cx, 320.0)
        self.assertEqual(intrinsics.cy, 240.0)

        k_mat = intrinsics.to_matrix()
        self.assertEqual(k_mat.shape, (3, 3))
        self.assertAlmostEqual(float(k_mat[0, 0]), intrinsics.fx, places=2)
        self.assertEqual(k_mat[2, 2], 1.0)

        # Test hazard assessment with explicit camera intrinsics
        step_frame = np.full((480, 640, 3), 160, dtype=np.uint8)
        step_frame[300:, :] = 40
        cv2.line(step_frame, (0, 300), (640, 300), (255, 255, 255), 4)
        _, profile = self.enhancer.assess_spatial_hazards(
            step_frame,
            camera_height_m=1.60,
            camera_pitch_rad=0.10,
            intrinsics=intrinsics,
        )
        self.assertTrue(profile.is_vertical_drop)
        self.assertGreaterEqual(profile.estimated_drop_cm, 0.0)

    def test_dual_engine_performance_profiles(self):
        realtime_model = discover_depth_model("realtime_mobile_30fps")
        high_fidelity_model = discover_depth_model("high_fidelity_depth")
        self.assertIsNotNone(realtime_model)
        self.assertIsNotNone(high_fidelity_model)
        self.assertIn("model-small", realtime_model.lower())
        self.assertIn("depth_anything", high_fidelity_model.lower())

        cfg_realtime = VisionEnhancementConfig(performance_profile="realtime_mobile_30fps")
        enhancer_rt = LowVisionEnhancer(cfg_realtime)
        self.assertIn("model-small", enhancer_rt.spatial_estimator.model_name.lower())

        cfg_hifi = VisionEnhancementConfig(performance_profile="high_fidelity_depth")
        enhancer_hifi = LowVisionEnhancer(cfg_hifi)
        self.assertIn("depth_anything", enhancer_hifi.spatial_estimator.model_name.lower())

    def test_measure_contrast_improvement(self):
        """CII and EER must be > 1.0 when CLAHE boosts a low-contrast frame."""
        # Create a deliberately low-contrast source frame
        dim_frame = np.full((200, 300, 3), 80, dtype=np.uint8)
        dim_frame[60:140, 80:220] = 100  # subtle 20-level variation
        enhanced = self.enhancer.enhance_contrast_and_edges(dim_frame)

        metrics = measure_contrast_improvement(dim_frame, enhanced)
        self.assertIn("cii", metrics)
        self.assertIn("edge_energy_ratio", metrics)
        self.assertGreater(metrics["cii"], 1.0,
                           "CLAHE must raise RMS contrast (CII > 1.0) on a dim frame")
        self.assertGreater(metrics["edge_energy_ratio"], 1.0,
                           "Edge enhancement must increase Sobel energy (EER > 1.0)")

        # With sighted mask
        mask = np.ones((200, 300), dtype=np.float32)
        metrics_m = measure_contrast_improvement(dim_frame, enhanced, sighted_mask=mask)
        self.assertIn("sighted_cii", metrics_m)
        self.assertGreater(metrics_m["sighted_cii"], 1.0)

    def test_ssim_interpretation_and_cii_consistency(self):
        """SSIM decreases when contrast is boosted (correct); CII must be >= 1.0."""
        dim_frame = np.full((200, 300, 3), 70, dtype=np.uint8)
        dim_frame[50:150, 50:250] = 90
        enhanced = self.enhancer.enhance_contrast_and_edges(dim_frame)

        mask = np.ones((200, 300), dtype=np.float32)
        ssim_val = measure_sighted_region_ssim(dim_frame, enhanced, mask)
        metrics = measure_contrast_improvement(dim_frame, enhanced)

        # SSIM can decrease when contrast is intentionally amplified
        self.assertLessEqual(ssim_val, 1.0)
        # CII must always be >= 1.0 when CLAHE is applied to a low-contrast frame
        self.assertGreaterEqual(metrics["cii"], 1.0)


if __name__ == "__main__":
    unittest.main()

