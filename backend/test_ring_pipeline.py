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

    def test_identify_care_circle_member(self):
        # Layer 1: Consented family member
        result = self.monitor.identify_doorstep_person_or_role(
            device_id="front_doorbell",
            person_query_hint="Sarah Vance",
            patient_id="pat_42",
        )
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["identification_layer"], "care_circle_opt_in")
        self.assertEqual(result["person_name"], "Sarah Vance")
        self.assertTrue(result["is_trusted"])
        self.assertIn("Sarah Vance", result["spoken_announcement"])
        self.assertIn("BIPA 740 ILCS", result["privacy_compliance"]["standard"])

    def test_identify_semantic_role_courier(self):
        # Layer 2: Non-biometric semantic VLM classification
        result = self.monitor.identify_doorstep_person_or_role(
            device_id="front_doorbell",
            person_query_hint="Amazon delivery carrier",
            patient_id="pat_42",
        )
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["identification_layer"], "semantic_role_non_biometric")
        self.assertIn("Amazon", result["detected_role"])
        self.assertFalse(result["privacy_compliance"]["facial_vectors_extracted"])
        self.assertIn("Amazon delivery carrier", result["spoken_announcement"])

    def test_care_circle_management(self):
        # List care circle
        members = self.monitor.list_care_circle()
        self.assertGreaterEqual(len(members), 3)

        # Register new member
        enrolled = self.monitor.register_care_circle_member(
            member_id="aide_elena",
            name="Elena Rostova",
            relationship="Mobility Specialist",
            phone="+1-555-019-7733",
            bipa_gdpr_consent_verified=True,
        )
        self.assertEqual(enrolled["status"], "success")
        self.assertEqual(enrolled["member"]["name"], "Elena Rostova")


if __name__ == "__main__":
    unittest.main()
