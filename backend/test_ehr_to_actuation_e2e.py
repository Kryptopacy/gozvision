"""End-to-End EHR -> DAVE -> OpenCV Perception -> Voice/Haptic Actuation Integration Test.

Proves the complete closed-loop clinical vision architecture:
1. Ingests patient EHR diagnosis from HL7 FHIR Condition (H35.31 AMD) + Observation (20/200 VA).
2. Synthesizes a DiagnosisAdaptiveConfig (DAVE) with peripheral scotoma annulus weighting.
3. Processes real ground image (street1.jpg) with condition-tuned CLAHE and inpainting.
4. Verifies quantitative Contrast Improvement Index (CII >= 1.40) and Edge Energy (> 2.0x).
5. Executes AgenticVisionOrchestrator perception pass with calibrated metric photogrammetry.
6. Verifies voice actuation prompt delivers accurate physical drop warning.
7. Verifies downstream caregiver SOS escalation upon stumble telemetry.
"""
import unittest
from pathlib import Path
import cv2
import numpy as np

from gozvision_vision.cv_pipeline import (
    LowVisionEnhancer,
    VisionEnhancementConfig,
    build_config_from_diagnosis,
    measure_contrast_improvement,
)
from gozvision_agent.agentic_vision import AgenticVisionOrchestrator
from gozvision_agent.fhir_service import (
    FhirR4BundleBuilder,
    OphthalmicEncounterData,
    extract_conditions_from_bundle,
)

_DATASET_RAW = Path(__file__).resolve().parent / "evaluation" / "dataset" / "raw"


class TestEHRToActuationE2E(unittest.TestCase):
    def test_ehr_fhir_dave_closed_loop(self):
        # 1. Ingest FHIR Clinical Bundle for AMD Patient
        patient_id = "pat_amd_8421"
        encounter_data = OphthalmicEncounterData(
            patient_id=patient_id,
            patient_name="Arthur Pendelton",
            patient_dob="1951-03-22",
            patient_gender="male",
            encounter_id="enc_e2e_4910",
            encounter_date="2026-10-22T09:00:00Z",
            provider_id="doc_optometry_7",
            provider_name="Dr. Marcus Bell, OD",
            clinic_id="clinic_boston_lowvision",
            clinic_name="New England Eye Care Institute",
            chief_complaint="Patient struggles with curbs due to central scotoma",
            soap_note={
                "subjective": "Loss of central detail, difficulty navigating city curbs.",
                "objective": "VA OD: 20/200, OS: 20/150. Significant geographic atrophy OU.",
                "assessment": "Dry AMD (H35.31) with central scotoma.",
                "plan": "Deploy GozVision smart vision copilot with peripheral annulus magnification.",
            },
            visual_acuity_od="20/200",
            visual_acuity_os="20/150",
            conditions=[
                ("H35.31", "Non-exudative age-related macular degeneration", "267718000")
            ],
        )
        builder = FhirR4BundleBuilder(encounter_data)
        bundle = builder.to_bundle()
        self.assertEqual(bundle.get("resourceType"), "Bundle")

        # 2. Extract clinical codes and build DAVE profile
        diagnoses = extract_conditions_from_bundle(bundle)
        self.assertIn("H35.31", diagnoses)

        raw_img_path = _DATASET_RAW / "street1.jpg"
        self.assertTrue(raw_img_path.exists(), "street1.jpg must exist in dataset")
        frame = cv2.imread(str(raw_img_path))
        self.assertIsNotNone(frame)
        h, w = frame.shape[:2]

        dave_config = build_config_from_diagnosis(diagnoses, frame_shape=(h, w))
        self.assertEqual(dave_config.profile_name, "amd_peripheral_annulus")
        self.assertIsNotNone(dave_config.spatial_weight_map)
        self.assertEqual(dave_config.clahe_clip_limit, 4.5)

        # 3. Process frame with DAVE condition-specific enhancer
        vision_cfg = VisionEnhancementConfig(performance_profile="high_fidelity_depth")
        dave_enhancer = LowVisionEnhancer(config=vision_cfg, dave_config=dave_config)
        enhanced_frame, meta = dave_enhancer.process_frame(frame, mode="enhanced_contrast")
        self.assertEqual(meta.get("dave_profile"), "amd_peripheral_annulus")

        # 4. Verify measurable contrast gain in patient's functioning retinal zone
        cii_metrics = measure_contrast_improvement(frame, enhanced_frame, dave_config.spatial_weight_map)
        self.assertGreaterEqual(cii_metrics["cii"], 1.40,
                                f"DAVE must boost RMS contrast (got CII={cii_metrics['cii']})")
        self.assertGreaterEqual(cii_metrics["edge_energy_ratio"], 2.0,
                                f"DAVE must sharpen edges by >=2x (got EER={cii_metrics['edge_energy_ratio']})")

        # 5. Agentic Loop Perception & Decision Pass
        orchestrator = AgenticVisionOrchestrator(enhancer=dave_enhancer)
        trace = orchestrator.execute_hazard_mitigation_workflow(
            frame,
            patient_id=patient_id,
            telemetry_stumble_detected=False,
        )

        # Verify Perception Step
        p_step = trace.steps[0]
        self.assertEqual(p_step["step_type"], "perception")
        self.assertTrue(p_step["details"]["is_vertical_drop"])
        drop_cm = p_step["details"]["estimated_drop_cm"]
        self.assertGreaterEqual(drop_cm, 12.0)
        self.assertLessEqual(drop_cm, 38.0)

        # Verify Actuator Step delivers voice alert with metric drop size
        actuator_step = next(s for s in trace.steps if s["step_type"] == "actuator")
        spoken_prompt = actuator_step["details"]["spoken_prompt"]
        self.assertIn("Caution: Abrupt step down", spoken_prompt)
        self.assertIn(f"{int(drop_cm)}cm detected ahead", spoken_prompt)
        self.assertEqual(actuator_step["details"]["haptic_pattern"], "double_pulse")

        # 6. Verify Escalation when stumble telemetry is received
        sos_trace = orchestrator.execute_hazard_mitigation_workflow(
            frame,
            patient_id=patient_id,
            telemetry_stumble_detected=True,
        )
        sos_step = next(s for s in sos_trace.steps if s["component"] == "gozvision_agent.tools.send_sos_alert")
        self.assertEqual(sos_step["step_type"], "tool_call")
        self.assertIn("Autonomous SOS Escalation", sos_step["action"])
        self.assertIn(f"{drop_cm}cm drop", sos_step["details"]["tool_input"])
        self.assertTrue(sos_trace.human_approval_required)
        self.assertIn("Emergency SOS Alert Dispatched", sos_trace.final_action_taken)


if __name__ == "__main__":
    unittest.main()
