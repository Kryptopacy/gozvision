"""Tests for the GozVision MCP Server tools."""
import unittest
from gozvision_mcp.server import (
    clinical_knowledge_lookup,
    trigger_emergency_sos,
    draft_ambient_scribe_chart,
    ring_inspect_doorstep_safety,
    ring_triage_caretaker_event,
    ring_broadcast_intercom_chime,
    ring_list_monitored_devices,
    ring_identify_doorstep_entity,
    ring_list_care_circle,
    ring_register_care_circle_contact,
    amazon_pharmacy_reorder_drops,
)


class TestGozVisionMCP(unittest.TestCase):
    def test_clinical_knowledge_lookup(self):
        result = clinical_knowledge_lookup("light sensitivity photophobia")
        self.assertEqual(result["status"], "success")
        self.assertIn("results", result)
        self.assertGreater(len(result["results"]), 0)

    def test_trigger_emergency_sos_stub(self):
        result = trigger_emergency_sos(
            patient_id="pat_test_01",
            message="Patient reported severe pain and sudden darkness in right eye.",
            severity="high",
        )
        self.assertIn("status", result)
        self.assertEqual(result["patient_id"], "pat_test_01")

    def test_draft_ambient_scribe_chart(self):
        sample_transcript = (
            "Doctor: How have you been seeing since starting the latanoprost?\n"
            "Patient: The blurriness has settled down, but I get occasional mild stinging at night.\n"
            "Doctor: Understood. Let's check intraocular pressures today. OD is 15, OS is 16. "
            "Cornea is clear. Let's maintain once daily at bedtime and see you in 3 months."
        )
        result = draft_ambient_scribe_chart("enc_test_101", sample_transcript)
        self.assertIn(result["status"], ["success", "fallback"])
        self.assertEqual(result["encounter_id"], "enc_test_101")
        self.assertIn("chart", result)

    def test_ring_accessibility_tools(self):
        # 1. Test Doorstep inspection
        doorstep_res = ring_inspect_doorstep_safety("front_doorbell")
        self.assertEqual(doorstep_res["status"], "success")
        self.assertIn("accessibility_audio_prompt", doorstep_res)

        # 2. Test Caretaker event triage
        caretaker_res = ring_triage_caretaker_event(
            event_type="door_open",
            device_id="front_doorbell",
            patient_id="pat_test_01",
        )
        self.assertEqual(caretaker_res["status"], "success")
        self.assertEqual(caretaker_res["patient_id"], "pat_test_01")

        # 3. Test Intercom broadcast
        chime_res = ring_broadcast_intercom_chime(
            message="Doorstep is clear, caregiver has been notified.",
            device_id="front_doorbell",
        )
        self.assertEqual(chime_res["status"], "success")

        # 4. Test List monitored devices
        devices_res = ring_list_monitored_devices()
        self.assertEqual(devices_res["status"], "success")
        self.assertGreater(devices_res["count"], 0)

        # 5. Test Care Circle identification (Layer 1)
        identify_res = ring_identify_doorstep_entity(
            device_id="front_doorbell",
            person_query_hint="Sarah Vance",
            patient_id="pat_test_01",
        )
        self.assertEqual(identify_res["status"], "success")
        self.assertEqual(identify_res["identification_layer"], "care_circle_opt_in")
        self.assertEqual(identify_res["person_name"], "Sarah Vance")

        # 6. Test Semantic Role identification (Layer 2)
        role_res = ring_identify_doorstep_entity(
            device_id="front_doorbell",
            person_query_hint="Amazon package delivery",
            patient_id="pat_test_01",
        )
        self.assertEqual(role_res["status"], "success")
        self.assertEqual(role_res["identification_layer"], "semantic_role_non_biometric")
        self.assertFalse(role_res["privacy_compliance"]["facial_vectors_extracted"])

    def test_amazon_pharmacy_reorder_drops_standalone(self):
        # Direct-to-Consumer Standalone (no clinic_id required)
        result = amazon_pharmacy_reorder_drops(
            medication_name="Latanoprost 0.005% Ophthalmic Solution",
            patient_id="pat_standalone_99",
            delivery_speed="prime_same_day",
            clinic_id=None,
        )
        self.assertEqual(result["status"], "order_confirmed")
        self.assertFalse(result["hospital_affiliation_required"])
        self.assertIn("Direct-to-Consumer", result["access_model"])
        self.assertIn("Latanoprost", result["spoken_alexa_confirmation"])
        self.assertIn("Prime", result["estimated_delivery"])


if __name__ == "__main__":
    unittest.main()
