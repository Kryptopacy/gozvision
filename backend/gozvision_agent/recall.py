"""Recall & no-show automation — the Front Desk's outreach engine.

Computes a clinic's outreach worklist from its appointments and renders
channel-agnostic messages, then writes them to the `notifications` collection
(docs/DATA_MODEL.md) for delivery:

- **reminder** — upcoming unconfirmed appointments inside the horizon.
- **recovery** — recent no-shows; warm re-booking message.
- **recall** — patients due for their routine exam (no completed visit in
  `recall_interval_days` and nothing booked ahead).

Delivery is a seam: messages land as `status: 'queued'` documents. A sender
job (console logger today, AWS End User Messaging/SES or any SMS provider
later) drains the queue. Run as a CLI:

    python -m gozvision_agent.recall --clinic demo_clinic_001 [--horizon 14]
"""
import argparse
import os
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

from .db import service_client

_db = service_client()
SUPABASE_AVAILABLE = _db is not None


@dataclass
class AppointmentView:
    id: str
    patient_id: str
    status: str            # scheduled | confirmed | completed | no_show | cancelled
    start: datetime
    type: str = "exam"


@dataclass
class RecallItem:
    kind: str              # reminder | recovery | recall
    patient_id: str
    appointment_id: str | None
    due: datetime | None = field(default=None)

    @property
    def template(self) -> str:
        return {
            "reminder": "Hi! Reminder: your {apptype} is on {date} at {time}. "
                        "Reply to confirm, or call us if you need to reschedule.",
            "recovery": "Hi! We missed you at your {apptype} on {date}. "
                        "Your eye health matters — reply and we'll find a new time that works.",
            "recall": "Hi! You're due for your routine eye exam — it's been a while since "
                      "your last visit. Reply and we'll book you in.",
        }[self.kind]


def _parse_ts(value) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


def compute_recall_worklist(
    appointments: list[AppointmentView],
    now: datetime,
    horizon_days: int = 14,
    no_show_lookback_days: int = 30,
    recall_interval_days: int = 365,
) -> list[RecallItem]:
    """Pure core of the sweep — fully unit-testable.

    A patient appears at most once: recovery (a recent no-show) beats
    reminder, which beats the annual recall.
    """
    horizon_end = now + timedelta(days=horizon_days)
    no_show_start = now - timedelta(days=no_show_lookback_days)

    completed_by_patient: dict[str, datetime] = {}
    upcoming_by_patient: dict[str, AppointmentView] = {}
    items: dict[str, RecallItem] = {}

    for appt in appointments:
        if appt.status == "completed":
            last = completed_by_patient.get(appt.patient_id)
            if last is None or appt.start > last:
                completed_by_patient[appt.patient_id] = appt.start
        elif appt.status in ("scheduled", "confirmed") and now <= appt.start <= horizon_end:
            upcoming_by_patient[appt.patient_id] = appt

    for appt in appointments:
        if appt.status == "no_show" and no_show_start <= appt.start <= now:
            items[appt.patient_id] = RecallItem(
                "recovery", appt.patient_id, appt.id, appt.start)
        elif (appt.status == "scheduled" and appt.patient_id not in items
              and now <= appt.start <= horizon_end):
            items[appt.patient_id] = RecallItem(
                "reminder", appt.patient_id, appt.id, appt.start)

    for patient_id, appt in upcoming_by_patient.items():
        if patient_id in items:
            continue
        if appt.status == "scheduled":
            items[patient_id] = RecallItem(
                "reminder", patient_id, appt.id, appt.start)

    for patient_id, last_visit in completed_by_patient.items():
        if patient_id in items:
            continue
        if patient_id in upcoming_by_patient:
            continue
        if now - last_visit >= timedelta(days=recall_interval_days):
            items[patient_id] = RecallItem("recall", patient_id, None, last_visit)

    return sorted(items.values(), key=lambda r: r.due or now)


def render_message(item: RecallItem, patient_name: str = "there",
                   appointment_type: str = "eye exam") -> str:
    """Pure message rendering — the channel stays a provider decision."""
    base = item.template.format(
        apptype=appointment_type,
        date=item.due.strftime("%b %d") if item.due else "",
        time=item.due.strftime("%I:%M %p").lstrip("0") if item.due else "",
    )
    return f"{patient_name.split(' ')[0] if patient_name else 'there'}, {base}"


def run_sweep(clinic_id: str, horizon_days: int = 14) -> list[dict]:
    """Queries the clinic's appointments, computes the worklist, and writes
    queued notifications. Returns what was enqueued."""
    if not SUPABASE_AVAILABLE or _db is None:
        raise RuntimeError("Recall sweep requires SUPABASE_URL + SUPABASE_SERVICE_KEY.")

    now = datetime.now(timezone.utc)
    appt_rows = (_db.table("appointments")
                 .select("id,patient_id,status,start_at,type")
                 .eq("clinic_id", clinic_id).execute().data)
    appointments = []
    for row in appt_rows:
        start = _parse_ts(row.get("start_at"))
        if start is None:
            continue
        appointments.append(AppointmentView(
            id=row["id"],
            patient_id=row.get("patient_id", "?"),
            status=row.get("status", "scheduled"),
            start=start,
            type=row.get("type", "eye exam"),
        ))
    worklist = compute_recall_worklist(appointments, now, horizon_days=horizon_days)

    names: dict[str, str] = {}
    for row in (_db.table("patients")
                .select("id,name").eq("clinic_id", clinic_id).execute().data):
        names[row["id"]] = row.get("name", "there")

    enqueued = []
    pending = []
    for item in worklist:
        appt_type = next(
            (a.type for a in appointments if a.id == item.appointment_id), "eye exam")
        message = render_message(item, names.get(item.patient_id, "there"), appt_type)
        pending.append({
            "clinic_id": clinic_id,
            "patient_id": item.patient_id,
            "appointment_id": item.appointment_id,
            "kind": item.kind,
            "channel": "sms",
            "message": message,
            "status": "queued",
            "created_at": now.isoformat(),
        })
        enqueued.append({"patientId": item.patient_id, "kind": item.kind,
                         "message": message})
    if pending:
        _db.table("notifications").insert(pending).execute()
    return enqueued


def _cli() -> None:
    parser = argparse.ArgumentParser(description="GozVision recall sweep")
    parser.add_argument("--clinic", required=True)
    parser.add_argument("--horizon", type=int, default=14)
    args = parser.parse_args()
    for entry in run_sweep(args.clinic, args.horizon):
        print(f"[{entry['kind']}] {entry['patientId']}: {entry['message']}")
    print("Sweep complete.")


if __name__ == "__main__":
    _cli()
