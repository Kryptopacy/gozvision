"""Seed a demo clinic world for the GozVision Clinic Suite.

Usage (needs Firebase Admin credentials via GOOGLE_APPLICATION_CREDENTIALS
or an ADC environment, plus FIREBASE_PROJECT_ID):

    cd backend
    python seed_clinic_demo.py [--project your-project-id] [--wipe]

Creates (deterministic ids so re-runs upsert):
  - clinic demo_clinic_001
  - auth users + user docs: practitioner@gozvision.demo (Practitioner),
    staff@gozvision.demo (Staff), caregiver@gozvision.demo (Caregiver)
  - 3 patients, 4 referrals across statuses, 5 device fits engineered to
    exercise the Low Vision Hub's abandonment-risk engine, today's
    appointments, and encounters with transcripts for the Scribe.

All passwords are "gozvision-demo". Never point this at production.
"""
import argparse
import os
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import auth as fb_auth
from firebase_admin import credentials, firestore

PASSWORD = "gozvision-demo"
NOW = datetime.now(timezone.utc)


def _ts(dt: datetime) -> datetime:
    return dt


def _ensure_user(email: str, uid: str, name: str) -> None:
    try:
        fb_auth.create_user(email=email, password=PASSWORD, uid=uid, display_name=name)
        print(f"  auth user created: {email}")
    except fb_auth.EmailAlreadyExistsError:
        print(f"  auth user exists:  {email}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=os.environ.get("FIREBASE_PROJECT_ID"))
    parser.add_argument("--wipe", action="store_true",
                        help="Delete collections under the demo clinic first")
    args = parser.parse_args()

    options = credentials.ApplicationDefault()
    if args.project:
        firebase_admin.initialize_app(options, {"projectId": args.project})
    else:
        firebase_admin.initialize_app(options)
    db = firestore.client()
    clinic = "demo_clinic_001"

    if args.wipe:
        for coll in ("patients", "appointments", "encounters", "low_vision_referrals",
                     "device_fits", "adherence_signals", "notifications"):
            for doc in db.collection(coll).where("clinicId", "==", clinic).stream():
                doc.reference.delete()
        print("wiped previous demo data")

    # ---- Clinic + staff ----------------------------------------------------
    db.collection("clinics").document(clinic).set({
        "name": "GozVision Demo Eye Clinic",
        "branch": "Main Street",
        "createdAt": _ts(NOW),
    })
    print("clinic seeded")

    _ensure_user("practitioner@gozvision.demo", "demo_practitioner_001", "Dr. Ada Optometrist")
    _ensure_user("staff@gozvision.demo", "demo_staff_001", "Sam Front Desk")
    _ensure_user("caregiver@gozvision.demo", "demo_caregiver_001", "Nina Caregiver")

    users = {
        "demo_practitioner_001": {
            "email": "practitioner@gozvision.demo", "name": "Dr. Ada Optometrist",
            "role": "Practitioner", "clinicId": clinic, "createdAt": _ts(NOW),
            "assigned_patients": [],
        },
        "demo_staff_001": {
            "email": "staff@gozvision.demo", "name": "Sam Front Desk",
            "role": "Staff", "clinicId": clinic, "createdAt": _ts(NOW),
            "assigned_patients": [],
        },
        "demo_caregiver_001": {
            "email": "caregiver@gozvision.demo", "name": "Nina Caregiver",
            "role": "Caregiver", "createdAt": _ts(NOW),
            "assigned_patients": ["demo_patient_001"],
        },
    }
    for uid, data in users.items():
        db.collection("users").document(uid).set(data)
    print("user docs seeded")

    # ---- Patients ----------------------------------------------------------
    patients = {
        "demo_patient_001": {"name": "Maria Santos", "age": 71,
                             "condition": "AMD (dry)", "phone": "+15550000001"},
        "demo_patient_002": {"name": "Chidi Okafor", "age": 58,
                             "condition": "Glaucoma suspect", "phone": "+15550000002"},
        "demo_patient_003": {"name": "Grace Adeyemi", "age": 66,
                             "condition": "Diabetic retinopathy", "phone": "+15550000003"},
    }
    for pid, p in patients.items():
        db.collection("patients").document(pid).set({
            **p, "clinicId": clinic, "practitionerId": "demo_practitioner_001",
            "createdAt": _ts(NOW),
        })
    print("patients seeded")

    # ---- Appointments (today + this week) ----------------------------------
    today = NOW.replace(hour=9, minute=0, second=0, microsecond=0)
    appointments = {
        "appt_1": ("demo_patient_001", "scheduled", today + timedelta(hours=2), "Comprehensive exam"),
        "appt_2": ("demo_patient_002", "confirmed", today + timedelta(hours=4), "Visual field test"),
        "appt_3": ("demo_patient_003", "scheduled", today + timedelta(days=1, hours=3), "Follow-up"),
        "appt_4": ("demo_patient_001", "no_show", NOW - timedelta(days=6), "IOP check"),
        "appt_5": ("demo_patient_002", "completed", NOW - timedelta(days=45), "Comprehensive exam"),
        "appt_6": ("demo_patient_003", "completed", NOW - timedelta(days=400), "Comprehensive exam"),
    }
    for aid, (pid, status, start, type_) in appointments.items():
        db.collection("appointments").document(aid).set({
            "clinicId": clinic, "patientId": pid, "practitionerId": "demo_practitioner_001",
            "status": status, "start": _ts(start), "type": type_,
        })
    print("appointments seeded")

    # ---- Referrals (every status, so the Hub panel shows the real picture) --
    referrals = {
        "ref_1": ("demo_patient_001", "attended"),
        "ref_2": ("demo_patient_002", "made"),
        "ref_3": ("demo_patient_003", "attended"),
        "ref_4": ("demo_patient_002", "lost_to_followup"),
    }
    for rid, (pid, status) in referrals.items():
        db.collection("low_vision_referrals").document(rid).set({
            "clinicId": clinic, "patientId": pid, "status": status,
            "from": "demo_practitioner_001", "createdAt": _ts(NOW - timedelta(days=30)),
        })
    print("referrals seeded")

    # ---- Device fits (engineered for the abandonment-risk engine) ----------
    fits = {
        # healthy: trialing with rich recent copilot activity
        "fit_1": ("demo_patient_001", "trialing", "handheld magnifier", "Optelec PowerMag 3", 12),
        # watch: trialing with sparse signals
        "fit_2": ("demo_patient_002", "trialing", "task lighting", "Lumie Task LED", 2),
        # elevated: trialing with NO signals — the abandonment signature
        "fit_3": ("demo_patient_003", "trialing", "electronic magnifier", "Enhance Vision HD", 0),
        "fit_4": ("demo_patient_001", "sustained", "software", "Goz copilot (PWA)", 9),
        "fit_5": ("demo_patient_002", "abandoned", "spotting scope", "Mounted monocular", 0),
    }
    for fid, (pid, status, dtype, model, signals) in fits.items():
        db.collection("device_fits").document(fid).set({
            "clinicId": clinic, "patientId": pid, "status": status,
            "device": {"type": dtype, "model": model},
            "trialEndsAt": _ts(NOW + timedelta(days=45)),
            "recentSignalCount": signals,  # denormalized by the backend job
            "fitAt": _ts(NOW - timedelta(days=15)),
        })
    print("device fits seeded")

    # ---- Adherence signals (for the healthy trialing fit) -------------------
    for i in range(10):
        db.collection("adherence_signals").add({
            "clinicId": clinic, "patientId": "demo_patient_001", "deviceFitId": "fit_1",
            "kind": ["daily_active_use", "task_completion", "session_duration"][i % 3],
            "value": 1, "at": _ts(NOW - timedelta(days=i)),
        })
    print("adherence signals seeded")

    # ---- Encounters with transcripts (so the Scribe has real input) ---------
    encounters = {
        "enc_1": ("demo_patient_001", "Low vision assessment",
                  "Patient: I struggle to read my medication bottles even with my glasses. "
                  "Doctor: Let's check your near vision. Read this line for me please. "
                  "Patient: I can only make out the big letters. "
                  "Doctor: Near vision is 20/80 at 40cm. We discussed a handheld "
                  "magnifier and I demonstrated it for her pill bottles, which helped. "
                  "Plan discussed: 45-day trial of the magnifier with follow-up."),
        "enc_2": ("demo_patient_002", "Visual field review",
                  "Doctor: Your field test shows some peripheral loss on the left, "
                  "consistent with what we are monitoring. Patient: I did notice bumping "
                  "into the doorframe on my left. Doctor: We reviewed drop adherence — "
                  "timolol every morning — and scheduled a pressure recheck in 4 weeks."),
    }
    for eid, (pid, type_, transcript) in encounters.items():
        db.collection("encounters").document(eid).set({
            "clinicId": clinic, "patientId": pid, "practitionerId": "demo_practitioner_001",
            "type": type_, "status": "completed",
            "transcript_text": transcript,
            "scribe_draft": {"status": "none"},
            "createdAt": _ts(NOW - timedelta(days=2)),
        })
    print("encounters seeded")

    print("\nDemo world ready. Clinic Suite logins (password: gozvision-demo):")
    print("  practitioner@gozvision.demo   (Low Vision Hub, Scribe review)")
    print("  staff@gozvision.demo          (Front Desk)")
    print("Copilot demo patient: demo_patient_001 — caregiver: caregiver@gozvision.demo")


if __name__ == "__main__":
    main()
