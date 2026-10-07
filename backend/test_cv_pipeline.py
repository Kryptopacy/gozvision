"""Unit test suite for GozVision's OpenCV 5 Accessibility Pipeline."""
import unittest
import numpy as np
import cv2

from gozvision_vision.cv_pipeline import LowVisionEnhancer, VisionEnhancementConfig


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
        for mode in ["enhanced_contrast", "glare_suppression", "reading"]:
            proc, meta = self.enhancer.process_frame(self.frame, mode=mode)
            self.assertEqual(proc.shape, self.frame.shape)
            self.assertEqual(meta["mode"], mode)


if __name__ == "__main__":
    unittest.main()
