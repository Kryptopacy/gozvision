"""Unit tests for GozVision Ring Accessibility & Caretaking Pipeline."""
import unittest
from gozvision_ring.ring_client import RingAccessibilityMonitor


class TestRingPipeline(unittest.TestCase):
    def setUp(self):
        self.monitor = RingAccessibilityMonitor()

    def test_list_devices(self):
        devices = self.monitor.list_devices()
        self.assertGreater(len(devices), 0)
        device_ids = [d["device_id"] for d in devices]
        self.assertIn("front_doorbell", device_ids)

    def test_inspect_doorstep_safety(self):
        result = self.monitor.inspect_doorstep_safety("front_doorbell")
        self.assertEqual(result["status"], "success")
        self.assertIn("accessibility_audio_prompt", result)
        self.assertIn("hazard_detected", result)

    def test_process_routine_caretaker_event(self):
        result = self.monitor.process_caretaker_event(
            event_type="routine_motion",
            device_id="hallway_indoor",
            patient_id="pat_42",
        )
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["patient_id"], "pat_42")

    def test_broadcast_intercom_chime(self):
        result = self.monitor.broadcast_intercom_chime(
            message="Dr. Miller's office has confirmed your low vision prescription.",
            device_id="front_doorbell",
        )
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["rendered_audio_status"], "queued_for_playback")


if __name__ == "__main__":
    unittest.main()
