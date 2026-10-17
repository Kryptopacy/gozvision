"""Seed a demo clinic world for the GozVision Clinic Suite (Supabase).

Usage (SUPABASE_URL + SUPABASE_SERVICE_KEY in backend/.env or env):

    cd backend
    python seed_clinic_demo.py [--wipe]

Creates (deterministic where possible; re-runnable):
  - clinic "GozVision Demo Eye Clinic"
  - auth users + profile rows: practitioner@gozvision.demo (Practitioner),
    staff@gozvision.demo (Staff), caregiver@gozvision.demo (Caregiver),
    demo-patient@gozvision.demo (Patient — the zero-UI copilot login)
  - patients (incl. the demo patient row keyed by its auth uid),
    4 referrals across statuses, 5 device fits engineered to exercise the
    Low Vision Hub's abandonment-risk engine, today's appointments (with a
    no-show and an annual-recall candidate), encounters with transcripts
    for the Scribe, and adherence signals for the healthy fit.

All passwords are "gozvision-demo". Never point this at production data.
"""
import argparse
import os
import uuid
from datetime import datetime, timedelta, timezone

from supabase import create_client

from gozvision_agent.db import load_env_files

load_env_files()

PASSWORD = "gozvision-demo"
NOW = datetime.now(timezone.utc)

USERS = {
    "practitioner@gozvision.demo": ("Dr. O.D. Adegoke", "Practitioner"),
    "staff@gozvision.demo": ("Sam Front Desk", "Staff"),
    "caregiver@gozvision.demo": ("Nina Caregiver", "Caregiver"),
    "demo-patient@gozvision.demo": ("Maria Santos", "Patient"),
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wipe", action="store_true",
                        help="Delete demo-clinic rows first")
    args = parser.parse_args()

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not url or not key:
        raise SystemExit("SUPABASE_URL and SUPABASE_SERVICE_KEY are required "
                         "(backend/.env or environment).")
    db = create_client(url, key)

    # ---- Auth users (get-or-create) ----------------------------------------
    uids = {}
    for email, (name, _role) in USERS.items():
        try:
            existing = db.auth.admin.list_users()
            match = next((u for u in existing if u.email == email), None)
        except Exception:
            match = None
        if match:
            uids[email] = match.id
            print(f"  auth user exists:  {email}")
        else:
            user = db.auth.admin.create_user({
                "email": email,
                "password": PASSWORD,
                "email_confirm": True,
                "user_metadata": {"name": name},
            })
            uids[email] = getattr(user, "user", user).id
            print(f"  auth user created: {email}")

    practitioner = uids["practitioner@gozvision.demo"]
    caregiver = uids["caregiver@gozvision.demo"]
    demo_patient_uid = uids["demo-patient@gozvision.demo"]

    # ---- Clinic -------------------------------------------------------------
    clinic_rows = db.table("clinics").select("id").eq("name", "GozVision Demo Eye Clinic").execute().data
    if clinic_rows:
        clinic = clinic_rows[0]["id"]
    else:
        clinic = str(uuid.uuid4())
        db.table("clinics").insert({
            "id": clinic, "name": "GozVision Demo Eye Clinic",
            "branch": "Main Street", "created_at": NOW.isoformat(),
        }).execute()
    print("clinic ready")

    if args.wipe:
        for table in ("patients", "appointments", "encounters",
                      "low_vision_referrals", "device_fits",
                      "adherence_signals", "notifications"):
            db.table(table).delete().eq("clinic_id", clinic).execute()
        print("wiped previous demo data")

    # ---- Profiles -----------------------------------------------------------
    profiles = {
        practitioner: {"email": "practitioner@gozvision.demo",
                       "name": "Dr. Ada Optometrist", "role": "Practitioner",
                       "clinic_id": clinic, "assigned_patients": []},
        uids["staff@gozvision.demo"]: {
            "email": "staff@gozvision.demo", "name": "Sam Front Desk",
            "role": "Staff", "clinic_id": clinic, "assigned_patients": []},
        caregiver: {"email": "caregiver@gozvision.demo",
                    "name": "Nina Caregiver", "role": "Caregiver",
                    "clinic_id": None,
                    "assigned_patients": [demo_patient_uid, "demo_patient_001"],
                    "caregiver_phone": "+15550000999"},
        demo_patient_uid: {"email": "demo-patient@gozvision.demo",
                           "name": "Maria Santos", "role": "Patient",
                           "clinic_id": clinic, "assigned_patients": []},
    }
    for uid, data in profiles.items():
        db.table("profiles").upsert({"id": uid, **data}).execute()
    print("profiles seeded")

    # ---- Patients -----------------------------------------------------------
    patients = {
        # The demo patient row is keyed by its auth uid: the copilot's
        # zero-UI session signs in as this account, so every write satisfies
        # RLS under a real identity (CONTEXT.md — Patient identity).
        demo_patient_uid: {"name": "Maria Santos", "age": 71,
                           "condition": "AMD (dry)", "phone": "+15550000001"},
        "demo_patient_002": {"name": "Chidi Okafor", "age": 58,
                             "condition": "Glaucoma suspect", "phone": "+15550000002"},
        "demo_patient_003": {"name": "Grace Adeyemi", "age": 66,
                             "condition": "Diabetic retinopathy", "phone": "+15550000003"},
    }
    for pid, p in patients.items():
        db.table("patients").upsert({
            "id": pid, **p, "clinic_id": clinic,
            "practitioner_id": practitioner, "created_at": NOW.isoformat(),
        }).execute()
    print("patients seeded")

    # ---- Appointments -------------------------------------------------------
    today = NOW.replace(hour=9, minute=0, second=0, microsecond=0)
    appointments = {
        "appt_1": (demo_patient_uid, "scheduled", today + timedelta(hours=2), "Comprehensive exam"),
        "appt_2": ("demo_patient_002", "confirmed", today + timedelta(hours=4), "Visual field test"),
        "appt_3": ("demo_patient_003", "scheduled", today + timedelta(days=1, hours=3), "Follow-up"),
        "appt_4": (demo_patient_uid, "no_show", NOW - timedelta(days=6), "IOP check"),
        "appt_5": ("demo_patient_002", "completed", NOW - timedelta(days=45), "Comprehensive exam"),
        "appt_6": ("demo_patient_003", "completed", NOW - timedelta(days=400), "Comprehensive exam"),
    }
    def to_uuid(s: str) -> str:
        return str(uuid.uuid5(uuid.NAMESPACE_DNS, s))

    appt_ids = [to_uuid(k) for k in appointments]
    db.table("appointments").delete().in_("id", appt_ids).execute()
    for aid, (pid, status, start, type_) in appointments.items():
        db.table("appointments").insert({
            "id": to_uuid(aid), "clinic_id": clinic, "patient_id": pid,
            "practitioner_id": practitioner, "status": status,
            "start_at": start.isoformat(), "type": type_,
        }).execute()
    print("appointments seeded")

    # ---- Referrals (every status, so the Hub panel shows the real picture) --
    ref_ids = [to_uuid(k) for k in ["ref_1", "ref_2", "ref_3", "ref_4"]]
    db.table("low_vision_referrals").delete().in_("id", ref_ids).execute()
    referrals = {
        "ref_1": (demo_patient_uid, "attended"),
        "ref_2": ("demo_patient_002", "made"),
        "ref_3": ("demo_patient_003", "attended"),
        "ref_4": ("demo_patient_002", "lost_to_followup"),
    }
    for rid, (pid, status) in referrals.items():
        db.table("low_vision_referrals").insert({
            "id": to_uuid(rid), "clinic_id": clinic, "patient_id": pid,
            "status": status, "from_practitioner_id": practitioner,
            "created_at": (NOW - timedelta(days=30)).isoformat(),
        }).execute()
    print("referrals seeded")

    # ---- Device fits (engineered for the abandonment-risk engine) ----------
    fit_ids = [to_uuid(k) for k in ["fit_1", "fit_2", "fit_3", "fit_4", "fit_5"]]
    db.table("device_fits").delete().in_("id", fit_ids).execute()
    fits = {
        # healthy: trialing with rich recent copilot activity
        "fit_1": (demo_patient_uid, "trialing", "handheld magnifier", "Optelec PowerMag 3", 12),
        # watch: trialing with sparse signals
        "fit_2": ("demo_patient_002", "trialing", "task lighting", "Lumie Task LED", 2),
        # elevated: trialing with NO signals — the abandonment signature
        "fit_3": ("demo_patient_003", "trialing", "electronic magnifier", "Enhance Vision HD", 0),
        "fit_4": (demo_patient_uid, "sustained", "software", "Goz copilot (PWA)", 9),
        "fit_5": ("demo_patient_002", "abandoned", "spotting scope", "Mounted monocular", 0),
    }
    for fid, (pid, status, dtype, model, signals) in fits.items():
        db.table("device_fits").insert({
            "id": to_uuid(fid), "clinic_id": clinic, "patient_id": pid, "status": status,
            "device": {"type": dtype, "model": model},
            "trial_ends_at": (NOW + timedelta(days=45)).isoformat(),
            "recent_signal_count": signals,  # denormalized by the backend job
            "fit_at": (NOW - timedelta(days=15)).isoformat(),
        }).execute()
    print("device fits seeded")

    # ---- Adherence signals (for the healthy trialing fit) -------------------
    for i in range(10):
        db.table("adherence_signals").insert({
            "clinic_id": clinic, "patient_id": demo_patient_uid,
            "device_fit_id": to_uuid("fit_1"),
            "kind": ["daily_active_use", "task_completion", "session_duration"][i % 3],
            "value": 1, "at": (NOW - timedelta(days=i)).isoformat(),
        }).execute()
    print("adherence signals seeded")

    # ---- Encounters with transcripts (so the Scribe has real input) ---------
    enc_ids = [to_uuid("enc_1"), to_uuid("enc_2")]
    db.table("encounters").delete().in_("id", enc_ids).execute()
    encounters = {
        "enc_1": (demo_patient_uid, "Low vision assessment",
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
        db.table("encounters").insert({
            "id": to_uuid(eid), "clinic_id": clinic, "patient_id": pid,
            "practitioner_id": practitioner, "type": type_, "status": "completed",
            "transcript_text": transcript,
            "scribe_draft": {"status": "none"},
            "created_at": (NOW - timedelta(days=2)).isoformat(),
        }).execute()
    print("encounters seeded")

    print("\nDemo world ready. Clinic Suite logins (password: gozvision-demo):")
    print("  practitioner@gozvision.demo   (Low Vision Hub, Scribe review)")
    print("  staff@gozvision.demo          (Front Desk)")
    print("Copilot demo patient login: demo-patient@gozvision.demo")
    print("Caregiver: caregiver@gozvision.demo")


if __name__ == "__main__":
    main()
