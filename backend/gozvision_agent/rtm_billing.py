"""CMS Remote Therapeutic Monitoring (RTM) Claim & Telemetry Billing Engine.

Automates qualification, calculation, and claim generation for CMS Remote
Therapeutic Monitoring codes under the Medicare Physician Fee Schedule:

- CPT 98975: Remote therapeutic monitoring device(s) supply with daily scheduled
             recordings and/or programmed transmissions, initial set-up and patient education.
             Reimbursement: ~$19.65 (One-time per episode of care).
- CPT 98980: Remote therapeutic monitoring treatment management services, physician/other
             qualified health care professional time in a calendar month requiring at least
             one interactive communication; first 20 minutes (≥16 transmission days).
             Reimbursement: ~$50.18 / calendar month.
- CPT 98981: Each additional 20 minutes of clinical treatment management services.
             Reimbursement: ~$39.72 / 20-minute increment.

Emits ANSI ASC X12N 837P electronic EDI claim transactions and CMS-1500 paper claim datasets.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, date, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class AdherenceTransmissionDay:
    """One day of recorded patient copilot / smart glasses transmission."""
    transmission_date: str      # YYYY-MM-DD
    active_minutes: float       # Minutes of copilot active visual guidance
    tasks_completed: int        # Reading sessions, orientation sweeps, navigation runs
    device_type: str = "GozVision Copilot / Smart Glasses"


@dataclass
class ClinicianEngagementLog:
    """Audit-proof log of practitioner / clinical staff review time."""
    timestamp: str              # ISO 8601
    duration_minutes: int       # Clinician review time
    clinician_npi: str
    clinician_name: str
    interaction_type: str       # "telehealth_audio", "in_person", "portal_review"
    clinical_notes: str


@dataclass
class RtmClaimLine:
    """Discrete CPT line item on a CMS-1500 / 837P claim."""
    cpt_code: str
    description: str
    units: int
    charge_usd: float
    service_date: str
    qualifying_days: int
    staff_minutes: int


class RtmBillingEngine:
    """Processes adherence telemetry and generates CMS-compliant RTM claims."""

    CPT_98975_RATE = 19.65
    CPT_98980_RATE = 50.18
    CPT_98981_RATE = 39.72
    MIN_TRANSMISSION_DAYS = 16  # CMS statutory 16-day transmission requirement per 30-day period

    def __init__(
        self,
        patient_id: str,
        patient_name: str,
        medicare_id: str,
        clinic_npi: str,
        billing_provider_npi: str,
        billing_provider_name: str,
        primary_icd10: str = "H35.31",  # Dry AMD
    ):
        self.patient_id = patient_id
        self.patient_name = patient_name
        self.medicare_id = medicare_id
        self.clinic_npi = clinic_npi
        self.billing_provider_npi = billing_provider_npi
        self.billing_provider_name = billing_provider_name
        self.primary_icd10 = primary_icd10

    def evaluate_monitoring_period(
        self,
        monitoring_period_start: str,
        monitoring_period_end: str,
        transmissions: List[AdherenceTransmissionDay],
        clinician_logs: List[ClinicianEngagementLog],
        is_initial_setup_period: bool = False,
    ) -> Dict[str, Any]:
        """Evaluates whether the 30-day period qualifies for CMS reimbursement."""
        unique_days = {t.transmission_date for t in transmissions if t.active_minutes > 0}
        total_transmission_days = len(unique_days)
        total_staff_minutes = sum(log.duration_minutes for log in clinician_logs)

        qualifies_transmissions = total_transmission_days >= self.MIN_TRANSMISSION_DAYS
        claim_lines: List[RtmClaimLine] = []

        # 1. CPT 98975 — Initial Setup & Patient Education (one-time upon onboarding)
        if is_initial_setup_period:
            claim_lines.append(
                RtmClaimLine(
                    cpt_code="98975",
                    description="RTM device initial set-up and patient education (Goz Copilot)",
                    units=1,
                    charge_usd=self.CPT_98975_RATE,
                    service_date=monitoring_period_start,
                    qualifying_days=total_transmission_days,
                    staff_minutes=0,
                )
            )

        # 2. CPT 98980 — First 20 mins clinical treatment management (requires ≥16 transmission days)
        if qualifies_transmissions and total_staff_minutes >= 20:
            claim_lines.append(
                RtmClaimLine(
                    cpt_code="98980",
                    description="RTM treatment management first 20 min clinical time",
                    units=1,
                    charge_usd=self.CPT_98980_RATE,
                    service_date=monitoring_period_end,
                    qualifying_days=total_transmission_days,
                    staff_minutes=20,
                )
            )

            # 3. CPT 98981 — Additional 20 min increments
            additional_minutes = total_staff_minutes - 20
            additional_blocks = additional_minutes // 20
            if additional_blocks > 0:
                claim_lines.append(
                    RtmClaimLine(
                        cpt_code="98981",
                        description=f"RTM treatment management additional 20 min ({additional_blocks} block(s))",
                        units=additional_blocks,
                        charge_usd=round(self.CPT_98981_RATE * additional_blocks, 2),
                        service_date=monitoring_period_end,
                        qualifying_days=total_transmission_days,
                        staff_minutes=additional_blocks * 20,
                    )
                )

        total_reimbursement = sum(line.charge_usd for line in claim_lines)

        return {
            "patient_id": self.patient_id,
            "period_start": monitoring_period_start,
            "period_end": monitoring_period_end,
            "days_transmitted": total_transmission_days,
            "meets_16_day_statutory_threshold": qualifies_transmissions,
            "total_clinician_minutes": total_staff_minutes,
            "qualified_for_billing": len(claim_lines) > 0,
            "total_estimated_reimbursement_usd": round(total_reimbursement, 2),
            "claim_lines": [
                {
                    "cpt": cl.cpt_code,
                    "desc": cl.description,
                    "units": cl.units,
                    "charge": cl.charge_usd,
                    "date": cl.service_date,
                }
                for cl in claim_lines
            ],
        }

    def generate_edi_837p_payload(
        self,
        evaluation_result: Dict[str, Any],
        claim_control_number: str = "GOZ-2026-001",
    ) -> str:
        """Generates ANSI ASC X12N 837P electronic claim format."""
        today_ymd = datetime.now().strftime("%Y%m%d")
        lines = []

        # ISA/GS Header
        lines.append(f"ISA*00*          *00*          *ZZ*GOZVISION      *ZZ*CMSCLEARING    *{today_ymd}*0830*^*00501*000000001*0*P*:~")
        lines.append(f"GS*HC*GOZVISION*CMSCLEARING*{today_ymd}*0830*1*X*005010X222A1~")
        lines.append("ST*837*0001*005010X222A1~")
        lines.append(f"BHT*0019*00*{claim_control_number}*{today_ymd}*0830*CH~")

        # Billing Provider Hierarchical Loop (2000A / 2010AA)
        lines.append("HL*1**20*1~")
        lines.append(f"NM1*85*2*{self.billing_provider_name}*****XX*{self.clinic_npi}~")

        # Subscriber / Patient Loop (2000B / 2010BA)
        lines.append("HL*2*1*22*0~")
        lines.append("SBR*P*18*******MB~")
        name_parts = self.patient_name.split(" ", 1)
        last_name = name_parts[1] if len(name_parts) > 1 else "PATIENT"
        first_name = name_parts[0] if name_parts else "DEMO"
        lines.append(f"NM1*IL*1*{last_name}*{first_name}****MI*{self.medicare_id}~")

        # Claim Loop (2300)
        total_charge = evaluation_result.get("total_estimated_reimbursement_usd", 0.0)
        lines.append(f"CLM*{claim_control_number}*{total_charge:.2f}***11:B:1*Y*A*Y*Y~")
        lines.append(f"HI*ABK:{self.primary_icd10.replace('.', '')}~")

        # Service Lines (2400)
        for idx, cl in enumerate(evaluation_result.get("claim_lines", [])):
            lines.append(f"LX*{idx+1}~")
            date_fmt = cl["date"].replace("-", "")
            lines.append(f"SV1*HC:{cl['cpt']}*{cl['charge']:.2f}*UN*{cl['units']}***1~")
            lines.append(f"DTP*472*D8*{date_fmt}~")

        # Trailer
        lines.append("SE*18*0001~")
        lines.append("GE*1*1~")
        lines.append("IEA*1*000000001~")

        return "\n".join(lines)
