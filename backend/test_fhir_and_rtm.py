"""Verification test suite for FHIR R4 Interoperability & CMS RTM Billing Engine."""
import base64
import unittest

from gozvision_agent.fhir_service import FhirR4BundleBuilder, OphthalmicEncounterData
from gozvision_agent.rtm_billing import (
    RtmBillingEngine,
    AdherenceTransmissionDay,
    ClinicianEngagementLog,
)


class TestFhirR4Interoperability(unittest.TestCase):

    def setUp(self):
        self.encounter_data = OphthalmicEncounterData(
            patient_id="pat_12345",
            patient_name="Eleanor Vance",
            patient_dob="1948-06-15",
            patient_gender="female",
            encounter_id="enc_98765",
            encounter_date="2026-10-15T14:30:00Z",
            provider_id="doc_miller",
            provider_name="Dr. Sarah Miller, OD",
            clinic_id="clinic_boston_eye",
            clinic_name="Boston Eye Rehabilitation Specialists",
            chief_complaint="Difficulty reading street signs and blurred central vision",
            soap_note={
                "subjective": "Patient reports worsening central scotoma OD > OS. Stumbled on curb last week.",
                "objective": "VA OD: 20/70, OS: 20/40. IOP OD: 18 mmHg, OS: 17 mmHg. Drusen visible macula OU.",
                "assessment": "Dry AMD (H35.31) with central scotoma; POAG (H40.11) stable on latanoprost.",
                "plan": "Onboard GozVision copilot with AMD peripheral annulus filter. Set up RTM monitoring.",
            },
            visual_acuity_od="20/70",
            visual_acuity_os="20/40",
            iop_od_mmhg=18.0,
            iop_os_mmhg=17.0,
        )
        self.builder = FhirR4BundleBuilder(self.encounter_data)

    def test_bundle_structure_and_us_core_profiles(self):
        bundle = self.builder.to_bundle()
        self.assertEqual(bundle["resourceType"], "Bundle")
        self.assertEqual(bundle["type"], "transaction")
        self.assertGreater(bundle["total"], 5)

        resources_by_type = {}
        for entry in bundle["entry"]:
            res = entry["resource"]
            resources_by_type.setdefault(res["resourceType"], []).append(res)

        # Check required resources
        self.assertIn("Patient", resources_by_type)
        self.assertIn("Encounter", resources_by_type)
        self.assertIn("Condition", resources_by_type)
        self.assertIn("Observation", resources_by_type)
        self.assertIn("DocumentReference", resources_by_type)
        self.assertIn("AuditEvent", resources_by_type)

        # Verify Patient US Core
        patient = resources_by_type["Patient"][0]
        self.assertIn("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient", patient["meta"]["profile"])
        self.assertEqual(patient["gender"], "female")
        self.assertEqual(patient["birthDate"], "1948-06-15")

        # Verify Visual Acuity Observation (LOINC 8684-3)
        obs_list = resources_by_type["Observation"]
        va_obs = next(o for o in obs_list if o["code"]["coding"][0]["code"] == "8684-3")
        self.assertEqual(va_obs["component"][0]["valueString"], "20/70")
        self.assertEqual(va_obs["component"][1]["valueString"], "20/40")

        # Verify IOP Observation (LOINC 75249-3)
        iop_obs = next(o for o in obs_list if o["code"]["coding"][0]["code"] == "75249-3")
        self.assertEqual(iop_obs["component"][0]["valueQuantity"]["value"], 18.0)
        self.assertEqual(iop_obs["component"][1]["valueQuantity"]["value"], 17.0)

        # Verify DocumentReference consultation note
        doc = resources_by_type["DocumentReference"][0]
        self.assertEqual(doc["type"]["coding"][0]["code"], "11488-4")
        data_b64 = doc["content"][0]["attachment"]["data"]
        decoded_text = base64.b64decode(data_b64).decode("utf-8")
        self.assertIn("OPHTHALMIC CONSULTATION & AMBIENT SCRIBE NOTE", decoded_text)
        self.assertIn("Drusen visible macula OU", decoded_text)


class TestCmsRtmBillingEngine(unittest.TestCase):

    def setUp(self):
        self.engine = RtmBillingEngine(
            patient_id="pat_12345",
            patient_name="Eleanor Vance",
            medicare_id="1EG4-TE5-MK72",
            clinic_npi="1982736450",
            billing_provider_npi="1122334455",
            billing_provider_name="BOSTON EYE CLINIC PC",
            primary_icd10="H35.31",
        )

    def test_under_16_days_does_not_qualify_cpt_98980(self):
        # 14 transmission days (< 16 days statutory threshold)
        transmissions = [
            AdherenceTransmissionDay(transmission_date=f"2026-10-{d:02d}", active_minutes=35.0, tasks_completed=4)
            for d in range(1, 15)
        ]
        logs = [
            ClinicianEngagementLog(
                timestamp="2026-10-20T10:00:00Z",
                duration_minutes=25,
                clinician_npi="1122334455",
                clinician_name="Dr. Sarah Miller",
                interaction_type="telehealth_audio",
                clinical_notes="Reviewed copilot adherence and obstacle alerts.",
            )
        ]

        result = self.engine.evaluate_monitoring_period(
            monitoring_period_start="2026-10-01",
            monitoring_period_end="2026-10-30",
            transmissions=transmissions,
            clinician_logs=logs,
            is_initial_setup_period=False,
        )

        self.assertFalse(result["meets_16_day_statutory_threshold"])
        self.assertEqual(result["days_transmitted"], 14)
        self.assertFalse(result["qualified_for_billing"])
        self.assertEqual(len(result["claim_lines"]), 0)

    def test_qualifying_rtm_period_with_cpt_98980_and_98981(self):
        # 20 transmission days (>= 16 days)
        transmissions = [
            AdherenceTransmissionDay(transmission_date=f"2026-10-{d:02d}", active_minutes=42.0, tasks_completed=5)
            for d in range(1, 21)
        ]
        # 45 minutes clinician review time (Qualifies CPT 98980 + 1 block of 98981)
        logs = [
            ClinicianEngagementLog(
                timestamp="2026-10-15T09:00:00Z",
                duration_minutes=25,
                clinician_npi="1122334455",
                clinician_name="Dr. Sarah Miller",
                interaction_type="portal_review",
                clinical_notes="Reviewing AMD adherence radar.",
            ),
            ClinicianEngagementLog(
                timestamp="2026-10-25T11:00:00Z",
                duration_minutes=20,
                clinician_npi="1122334455",
                clinician_name="Dr. Sarah Miller",
                interaction_type="telehealth_audio",
                clinical_notes="Discussing lighting optimization at home.",
            ),
        ]

        result = self.engine.evaluate_monitoring_period(
            monitoring_period_start="2026-10-01",
            monitoring_period_end="2026-10-30",
            transmissions=transmissions,
            clinician_logs=logs,
            is_initial_setup_period=True,  # Includes CPT 98975 onboarding
        )

        self.assertTrue(result["meets_16_day_statutory_threshold"])
        self.assertTrue(result["qualified_for_billing"])
        cpts = [cl["cpt"] for cl in result["claim_lines"]]
        self.assertIn("98975", cpts)
        self.assertIn("98980", cpts)
        self.assertIn("98981", cpts)
        # 19.65 + 50.18 + 39.72 = 109.55
        self.assertEqual(result["total_estimated_reimbursement_usd"], 109.55)

        # Test EDI 837P Generation
        edi_payload = self.engine.generate_edi_837p_payload(result, claim_control_number="CLAIM-2026-EV01")
        self.assertIn("ISA*00*", edi_payload)
        self.assertIn("CLM*CLAIM-2026-EV01*109.55", edi_payload)
        self.assertIn("SV1*HC:98980*50.18", edi_payload)
        self.assertIn("SV1*HC:98981*39.72", edi_payload)
        self.assertIn("HI*ABK:H3531", edi_payload)


if __name__ == "__main__":
    unittest.main()
