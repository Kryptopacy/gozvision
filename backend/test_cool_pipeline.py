"""Unit and integration test suite for GozVision COOL on AWS Graviton pipeline."""
import unittest
import numpy as np

from gozvision_vision.cool_pipeline import CoolGravitonPipeline, GravitonOptimizationProfile


class TestCoolGravitonPipeline(unittest.TestCase):
    def setUp(self):
        self.pipeline = CoolGravitonPipeline()
        self.frame = np.full((480, 640, 3), 140, dtype=np.uint8)

    def test_system_telemetry(self):
        telemetry = self.pipeline.get_system_telemetry()
        self.assertIn("platform_architecture", telemetry)
        self.assertIn("opencv_version", telemetry)
        self.assertIn("simd_vector_extensions", telemetry)
        self.assertIn("cool_accelerated", telemetry)
        self.assertIn("target_instance_type", telemetry)
        self.assertIn("instance_cost_per_hour_usd", telemetry)
        self.assertGreater(telemetry["instance_cost_per_hour_usd"], 0.0)

    def test_single_frame_processing_telemetry(self):
        out, meta = self.pipeline.process_frame(self.frame, mode="enhanced_contrast")
        self.assertEqual(out.shape, self.frame.shape)
        self.assertIn("latency_ms", meta)
        self.assertIn("effective_fps", meta)
        self.assertGreater(meta["effective_fps"], 0.0)

    def test_batch_processing_and_cloud_cost_metrics(self):
        frames = [self.frame.copy() for _ in range(5)]
        processed_frames, bench = self.pipeline.process_batch(frames, mode="glare_suppression")
        self.assertEqual(len(processed_frames), 5)
        self.assertEqual(bench.batch_size, 5)
        self.assertGreater(bench.throughput_fps, 0.0)
        self.assertGreater(bench.cost_per_million_frames_usd, 0.0)
        self.assertLess(bench.cost_per_million_frames_usd, 1.0)  # Should be pennies per million frames


if __name__ == "__main__":
    unittest.main()
