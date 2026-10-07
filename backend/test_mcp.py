"""Tests for the GozVision MCP Server tools."""
import unittest
from gozvision_mcp.server import (
    clinical_knowledge_lookup,
    trigger_emergency_sos,
    draft_ambient_scribe_chart,
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


if __name__ == "__main__":
    unittest.main()
