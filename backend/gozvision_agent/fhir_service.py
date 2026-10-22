"""HL7 FHIR Release 4 & ONC USCDI v3 Interoperability Engine.

Bridges GozVision clinical encounter data, Scribe SOAP documentation, and
patient telemetry into standardized FHIR R4 resources certified for:
- Epic Systems (MyChart / Hyperspace via SMART on FHIR OAuth 2.0)
- Eyefinity EHR / OfficeMate
- RevolutionEHR
- ModMed EMA
- Compulink Advantage

Complies strictly with US Core Implementation Guide (STU3/STU4) and USCDI v3.
"""
from __future__ import annotations

import base64
from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
import uuid
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class OphthalmicEncounterData:
    """Discrete clinical encounter parameters for FHIR R4 export."""
    patient_id: str
    patient_name: str
    patient_dob: str
    patient_gender: str
    encounter_id: str
    encounter_date: str
    provider_id: str
    provider_name: str
    clinic_id: str
    clinic_name: str
    chief_complaint: str
    soap_note: Dict[str, str]
    # Discrete eye metrics
    visual_acuity_od: str = "20/40"
    visual_acuity_os: str = "20/30"
    iop_od_mmhg: float = 16.0
    iop_os_mmhg: float = 17.0
    # Ocular and systemic diagnoses (ICD-10-CM / SNOMED CT)
    conditions: List[Tuple[str, str, str]] = field(default_factory=lambda: [
        ("H35.31", "Non-exudative age-related macular degeneration", "267718000"),
        ("H40.11", "Primary open-angle glaucoma", "392288001"),
    ])


class FhirR4BundleBuilder:
    """Constructs compliant HL7 FHIR R4 Transaction Bundles."""

    def __init__(self, encounter: OphthalmicEncounterData):
        self.enc = encounter
        self.base_url = "urn:uuid:"
        self.timestamp = datetime.now(timezone.utc).isoformat()

    def build_patient_resource(self) -> Dict[str, Any]:
        """FHIR R4 US Core Patient profile."""
        name_parts = self.enc.patient_name.split(" ", 1)
        given = [name_parts[0]] if name_parts else ["Unknown"]
        family = name_parts[1] if len(name_parts) > 1 else "Patient"

        return {
            "resourceType": "Patient",
            "id": self.enc.patient_id,
            "meta": {
                "profile": ["http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient"]
            },
            "identifier": [
                {
                    "use": "usual",
                    "type": {
                        "coding": [
                            {"system": "http://terminology.hl7.org/CodeSystem/v2-0203", "code": "MR", "display": "Medical Record Number"}
                        ]
                    },
                    "system": f"https://gozvision.com/clinics/{self.enc.clinic_id}/patients",
                    "value": self.enc.patient_id,
                }
            ],
            "active": True,
            "name": [{"use": "official", "family": family, "given": given}],
            "gender": self.enc.patient_gender.lower(),
            "birthDate": self.enc.patient_dob,
        }

    def build_encounter_resource(self) -> Dict[str, Any]:
        """FHIR R4 US Core Encounter profile."""
        return {
            "resourceType": "Encounter",
            "id": self.enc.encounter_id,
            "meta": {
                "profile": ["http://hl7.org/fhir/us/core/StructureDefinition/us-core-encounter"]
            },
            "status": "finished",
            "class": {
                "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
                "code": "AMB",
                "display": "ambulatory",
            },
            "type": [
                {
                    "coding": [
                        {
                            "system": "http://snomed.info/sct",
                            "code": "371531000",
                            "display": "Report of consultation",
                        }
                    ],
                    "text": "Ophthalmic Comprehensive Consultation & Low-Vision Evaluation",
                }
            ],
            "subject": {"reference": f"Patient/{self.enc.patient_id}"},
            "participant": [
                {
                    "type": [
                        {
                            "coding": [
                                {
                                    "system": "http://terminology.hl7.org/CodeSystem/v3-ParticipationType",
                                    "code": "PPRF",
                                    "display": "primary performer",
                                }
                            ]
                        }
                    ],
                    "individual": {
                        "display": self.enc.provider_name,
                        "reference": f"Practitioner/{self.enc.provider_id}",
                    },
                }
            ],
            "period": {"start": self.enc.encounter_date, "end": self.enc.encounter_date},
            "reasonCode": [{"text": self.enc.chief_complaint}],
        }

    def build_condition_resources(self) -> List[Dict[str, Any]]:
        """FHIR R4 US Core Condition profiles for ocular diagnoses."""
        resources = []
        for idx, (icd10, desc, snomed) in enumerate(self.enc.conditions):
            cond_id = f"cond-{self.enc.encounter_id}-{idx+1}"
            resources.append({
                "resourceType": "Condition",
                "id": cond_id,
                "meta": {
                    "profile": ["http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition-problems-health-concerns"]
                },
                "clinicalStatus": {
                    "coding": [
                        {"system": "http://terminology.hl7.org/CodeSystem/condition-clinical", "code": "active"}
                    ]
                },
                "verificationStatus": {
                    "coding": [
                        {"system": "http://terminology.hl7.org/CodeSystem/condition-ver-status", "code": "confirmed"}
                    ]
                },
                "category": [
                    {
                        "coding": [
                            {
                                "system": "http://terminology.hl7.org/CodeSystem/condition-category",
                                "code": "problem-list-item",
                                "display": "Problem List Item",
                            }
                        ]
                    }
                ],
                "code": {
                    "coding": [
                        {"system": "http://hl7.org/fhir/sid/icd-10-cm", "code": icd10, "display": desc},
                        {"system": "http://snomed.info/sct", "code": snomed, "display": desc},
                    ],
                    "text": desc,
                },
                "subject": {"reference": f"Patient/{self.enc.patient_id}"},
                "encounter": {"reference": f"Encounter/{self.enc.encounter_id}"},
            })
        return resources

    def build_observation_resources(self) -> List[Dict[str, Any]]:
        """FHIR R4 US Core Observations for Visual Acuity and Intraocular Pressure (IOP)."""
        observations = []

        # 1. Visual Acuity (OD & OS) - LOINC 8684-3
        observations.append({
            "resourceType": "Observation",
            "id": f"obs-va-{self.enc.encounter_id}",
            "meta": {
                "profile": ["http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-clinical-result"]
            },
            "status": "final",
            "category": [
                {
                    "coding": [
                        {"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "exam"}
                    ]
                }
            ],
            "code": {
                "coding": [
                    {"system": "http://loinc.org", "code": "8684-3", "display": "Visual acuity Snellen uncorrected"}
                ],
                "text": "Visual Acuity Distance",
            },
            "subject": {"reference": f"Patient/{self.enc.patient_id}"},
            "encounter": {"reference": f"Encounter/{self.enc.encounter_id}"},
            "effectiveDateTime": self.enc.encounter_date,
            "component": [
                {
                    "code": {
                        "coding": [{"system": "http://loinc.org", "code": "28631-0", "display": "Visual acuity OD Snellen"}]
                    },
                    "valueString": self.enc.visual_acuity_od,
                },
                {
                    "code": {
                        "coding": [{"system": "http://loinc.org", "code": "28632-8", "display": "Visual acuity OS Snellen"}]
                    },
                    "valueString": self.enc.visual_acuity_os,
                },
            ],
        })

        # 2. Intraocular Pressure (IOP) - LOINC 75249-3
        observations.append({
            "resourceType": "Observation",
            "id": f"obs-iop-{self.enc.encounter_id}",
            "meta": {
                "profile": ["http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-clinical-result"]
            },
            "status": "final",
            "category": [
                {
                    "coding": [
                        {"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "exam"}
                    ]
                }
            ],
            "code": {
                "coding": [
                    {"system": "http://loinc.org", "code": "75249-3", "display": "Intraocular pressure by Tonometry"}
                ],
                "text": "Intraocular Pressure (Goldmann Applanation)",
            },
            "subject": {"reference": f"Patient/{self.enc.patient_id}"},
            "encounter": {"reference": f"Encounter/{self.enc.encounter_id}"},
            "effectiveDateTime": self.enc.encounter_date,
            "component": [
                {
                    "code": {
                        "coding": [{"system": "http://loinc.org", "code": "75247-7", "display": "Intraocular pressure OD"}]
                    },
                    "valueQuantity": {"value": self.enc.iop_od_mmhg, "unit": "mmHg", "system": "http://unitsofmeasure.org", "code": "mm[Hg]"},
                },
                {
                    "code": {
                        "coding": [{"system": "http://loinc.org", "code": "75248-5", "display": "Intraocular pressure OS"}]
                    },
                    "valueQuantity": {"value": self.enc.iop_os_mmhg, "unit": "mmHg", "system": "http://unitsofmeasure.org", "code": "mm[Hg]"},
                },
            ],
        })

        return observations

    def build_document_reference_resource(self) -> Dict[str, Any]:
        """FHIR R4 US Core DocumentReference for Ambient Scribe SOAP consultation note."""
        soap = self.enc.soap_note
        raw_text = (
            f"=== OPHTHALMIC CONSULTATION & AMBIENT SCRIBE NOTE ===\n"
            f"Patient: {self.enc.patient_name} (MRN: {self.enc.patient_id})\n"
            f"Provider: {self.enc.provider_name}\n"
            f"Date: {self.enc.encounter_date}\n\n"
            f"SUBJECTIVE:\n{soap.get('subjective', 'Non-contributory')}\n\n"
            f"OBJECTIVE:\n{soap.get('objective', f'VA OD: {self.enc.visual_acuity_od}, OS: {self.enc.visual_acuity_os}. IOP OD: {self.enc.iop_od_mmhg} mmHg, OS: {self.enc.iop_os_mmhg} mmHg.')}\n\n"
            f"ASSESSMENT:\n{soap.get('assessment', 'Low vision secondary to dry AMD and POAG.')}\n\n"
            f"PLAN:\n{soap.get('plan', 'Prescribe GozVision assistive copilot; schedule 30-day RTM review.')}\n"
        )
        b64_content = base64.b64encode(raw_text.encode("utf-8")).decode("utf-8")

        return {
            "resourceType": "DocumentReference",
            "id": f"doc-soap-{self.enc.encounter_id}",
            "meta": {
                "profile": ["http://hl7.org/fhir/us/core/StructureDefinition/us-core-documentreference"]
            },
            "status": "current",
            "type": {
                "coding": [
                    {"system": "http://loinc.org", "code": "11488-4", "display": "Consultation note"}
                ],
                "text": "Ophthalmic Consultation & Scribe SOAP Chart",
            },
            "category": [
                {
                    "coding": [
                        {"system": "http://hl7.org/fhir/us/core/CodeSystem/us-core-documentreference-category", "code": "clinical-note"}
                    ]
                }
            ],
            "subject": {"reference": f"Patient/{self.enc.patient_id}"},
            "date": self.timestamp,
            "author": [{"display": self.enc.provider_name, "reference": f"Practitioner/{self.enc.provider_id}"}],
            "context": {"encounter": [{"reference": f"Encounter/{self.enc.encounter_id}"}]},
            "content": [
                {
                    "attachment": {
                        "contentType": "text/plain",
                        "language": "en-US",
                        "data": b64_content,
                        "title": f"GozVision SOAP Consultation Note - {self.enc.encounter_date}",
                    }
                }
            ],
        }

    def build_audit_event_resource(self) -> Dict[str, Any]:
        """FHIR R4 AuditEvent for HIPAA access audit logging."""
        return {
            "resourceType": "AuditEvent",
            "id": f"audit-{uuid.uuid4()}",
            "type": {
                "system": "http://dicom.nema.org/resources/ontology/DCM",
                "code": "110100",
                "display": "Application Activity",
            },
            "subtype": [
                {"system": "http://hl7.org/fhir/restful-interaction", "code": "create", "display": "Create"}
            ],
            "action": "C",
            "recorded": self.timestamp,
            "outcome": "0",
            "agent": [
                {
                    "type": {
                        "coding": [
                            {"system": "http://terminology.hl7.org/CodeSystem/v3-ParticipationType", "code": "AUT"}
                        ]
                    },
                    "who": {"display": "GozVision SMART on FHIR Interop Hub"},
                    "requestor": True,
                }
            ],
            "source": {
                "observer": {"display": "GozVision Clinic Suite Ingress"},
                "type": [{"system": "http://terminology.hl7.org/CodeSystem/security-source-type", "code": "4"}],
            },
            "entity": [
                {
                    "what": {"reference": f"Encounter/{self.enc.encounter_id}"},
                    "type": {"system": "http://terminology.hl7.org/CodeSystem/audit-entity-type", "code": "2"},
                }
            ],
        }

    def to_bundle(self) -> Dict[str, Any]:
        """Assembles all resources into an atomic FHIR R4 Transaction Bundle."""
        patient = self.build_patient_resource()
        encounter = self.build_encounter_resource()
        conditions = self.build_condition_resources()
        observations = self.build_observation_resources()
        doc_ref = self.build_document_reference_resource()
        audit = self.build_audit_event_resource()

        all_resources = [patient, encounter] + conditions + observations + [doc_ref, audit]

        entries = []
        for r in all_resources:
            entries.append({
                "fullUrl": f"{self.base_url}{r['resourceType']}-{r['id']}",
                "resource": r,
                "request": {
                    "method": "POST",
                    "url": r["resourceType"],
                },
            })

        return {
            "resourceType": "Bundle",
            "id": f"bundle-encounter-{self.enc.encounter_id}",
            "type": "transaction",
            "timestamp": self.timestamp,
            "entry": entries,
            "total": len(entries),
        }


def extract_conditions_from_bundle(bundle: Dict[str, Any]) -> List[str]:
    """Extract all condition ICD-10/SNOMED codes from a FHIR R4 Bundle."""
    codes: List[str] = []
    for entry in bundle.get("entry", []):
        resource = entry.get("resource", {})
        if resource.get("resourceType") == "Condition":
            code_block = resource.get("code", {})
            for coding in code_block.get("coding", []):
                val = coding.get("code")
                if val and val not in codes:
                    codes.append(val)
    return codes

