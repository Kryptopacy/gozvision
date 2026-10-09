"""Test suite for GozVision Agentic Vision perception-decision-action feedback loops."""
import unittest
import numpy as np
import cv2

from gozvision_agent.agentic_vision import AgenticVisionOrchestrator


class TestAgenticVisionFeedbackLoop(unittest.TestCase):
    def setUp(self):
        self.orchestrator = AgenticVisionOrchestrator()

        # Frame 1: Clear pathway
        self.clear_frame = np.full((480, 640, 3), 150, dtype=np.uint8)

        # Frame 2: High hazard curb transition
        self.hazard_frame = np.full((480, 640, 3), 150, dtype=np.uint8)
        self.hazard_frame[240:480, :] = 60
        # Draw high-contrast edge boundaries
        for y in range(250, 470, 20):
            cv2.line(self.hazard_frame, (50, y), (590, y), (255, 255, 255), 3)

        # Frame 3: Prescription label frame with simulated text
        self.label_frame = np.full((480, 640, 3), 200, dtype=np.uint8)
        cv2.rectangle(self.label_frame, (100, 150), (540, 320), (255, 255, 255), -1)
        cv2.putText(
            self.label_frame,
            "TIMOLOL 0.5% OPHTHALMIC",
            (120, 230),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 0, 0),
            2,
        )

    def test_perception_metrics_extraction(self):
        metrics = self.orchestrator.analyze_frame_perception(self.hazard_frame)
        self.assertGreater(metrics.hazard_salience_score, 0.0)
        self.assertTrue(metrics.hazard_detected)

    def test_hazard_mitigation_clear_path(self):
        trace = self.orchestrator.execute_hazard_mitigation_workflow(
            frame=self.clear_frame,
            telemetry_stumble_detected=False,
        )
        self.assertTrue(trace.success)
        self.assertFalse(trace.human_approval_required)
        self.assertEqual(trace.final_action_taken, "Passive Ambient Monitoring Maintained")

    def test_hazard_mitigation_stumble_escalation(self):
        # OpenCV output + stumble telemetry MUST trigger emergency SOS dispatch
        trace = self.orchestrator.execute_hazard_mitigation_workflow(
            frame=self.hazard_frame,
            telemetry_stumble_detected=True,
        )
        self.assertTrue(trace.success)
        self.assertTrue(trace.human_approval_required)
        self.assertIn("Emergency SOS Alert Dispatched", trace.final_action_taken)

        # Verify multi-step trace integrity
        step_types = [s["step_type"] for s in trace.steps]
        self.assertIn("perception", step_types)
        self.assertIn("reasoning", step_types)
        self.assertIn("actuator", step_types)
        self.assertIn("tool_call", step_types)

    def test_medication_guardrail_contraindication_halts_action(self):
        # Frame with text + unrecognized drop -> Agent MUST HALT and request clinician review
        trace = self.orchestrator.execute_medication_guardrail_workflow(
            frame=self.label_frame,
            ocr_extracted_text="Alphagan P 0.15% (Brimonidine)",
        )
        self.assertTrue(trace.success)
        self.assertTrue(trace.human_approval_required)
        self.assertIn("Administration Halted", trace.final_action_taken)

        step_types = [s["step_type"] for s in trace.steps]
        self.assertIn("perception", step_types)
        self.assertIn("tool_call", step_types)
        self.assertIn("human_escalation", step_types)

    def test_medication_guardrail_verified_adherence(self):
        # Prescribed drop matches Latanoprost -> logs adherence
        trace = self.orchestrator.execute_medication_guardrail_workflow(
            frame=self.label_frame,
            ocr_extracted_text="Latanoprost 0.005% Ophthalmic Solution",
        )
        self.assertTrue(trace.success)
        self.assertFalse(trace.human_approval_required)
        self.assertIn("Adherence Streak Successfully Logged", trace.final_action_taken)


if __name__ == "__main__":
    unittest.main()
