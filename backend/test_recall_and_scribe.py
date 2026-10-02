"""Offline tests for the Scribe and recall engines (pure logic only).

Run from backend/: python test_recall_and_scribe.py
"""
import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from gozvision_agent.recall import (  # noqa: E402
    AppointmentView,
    RecallItem,
    compute_recall_worklist,
    render_message,
)
from gozvision_agent.scribe import build_chart_prompt, parse_chart  # noqa: E402

NOW = datetime(2026, 10, 2, 9, 0, tzinfo=timezone.utc)


def appt(aid, pid, status, start, type_="eye exam"):
    return AppointmentView(id=aid, patient_id=pid, status=status, start=start, type=type_)


# ---- Recall worklist -------------------------------------------------------

def test_upcoming_unconfirmed_appointment_gets_a_reminder():
    appts = [appt("a1", "p1", "scheduled", NOW + timedelta(days=3))]
    worklist = compute_recall_worklist(appts, NOW)
    assert [w.kind for w in worklist] == ["reminder"]
    assert worklist[0].appointment_id == "a1"


def test_confirmed_appointments_are_left_alone():
    appts = [appt("a1", "p1", "confirmed", NOW + timedelta(days=3))]
    assert compute_recall_worklist(appts, NOW) == []


def test_recent_no_show_gets_recovery_over_reminder():
    appts = [
        appt("a1", "p1", "no_show", NOW - timedelta(days=5)),
        appt("a2", "p1", "scheduled", NOW + timedelta(days=4)),
    ]
    worklist = compute_recall_worklist(appts, NOW)
    assert [w.kind for w in worklist] == ["recovery"]


def test_annual_recall_for_overdue_completed_visit():
    appts = [appt("a1", "p1", "completed", NOW - timedelta(days=400))]
    worklist = compute_recall_worklist(appts, NOW)
    assert [w.kind for w in worklist] == ["recall"]


def test_recent_visit_with_future_booking_gets_nothing():
    appts = [
        appt("a1", "p1", "completed", NOW - timedelta(days=60)),
        appt("a2", "p1", "confirmed", NOW + timedelta(days=30)),
    ]
    assert compute_recall_worklist(appts, NOW) == []


def test_one_message_per_patient_max():
    appts = [
        appt("a1", "p1", "no_show", NOW - timedelta(days=3)),
        appt("a2", "p1", "scheduled", NOW + timedelta(days=2)),
        appt("a3", "p1", "scheduled", NOW + timedelta(days=9)),
    ]
    assert len(compute_recall_worklist(appts, NOW)) == 1


def test_no_shows_older_than_lookback_are_ignored():
    appts = [appt("a1", "p1", "no_show", NOW - timedelta(days=60))]
    assert compute_recall_worklist(appts, NOW) == []


# ---- Message rendering -----------------------------------------------------

def test_messages_name_the_patient_and_the_date():
    item = RecallItem("reminder", "p1", "a1", datetime(2026, 10, 9, 14, 30, tzinfo=timezone.utc))
    msg = render_message(item, "Maria Santos", "dilated exam")
    assert msg.startswith("Maria,")
    assert "Oct 09" in msg
    assert "2:30 PM" in msg
    assert "dilated exam" in msg


# ---- Scribe prompt + parsing ----------------------------------------------

def test_chart_prompt_carries_the_conversation_and_guardrails():
    prompt = build_chart_prompt("Patient: my vision is blurry up close.")
    assert "optometric scribe" in prompt
    assert "[not documented]" in prompt
    assert "blurry up close" in prompt
    assert "SUBJECTIVE:" in prompt


def test_parse_chart_extracts_all_four_sections():
    sample = """SUBJECTIVE: Reports blurry near vision, worse in the evening.
OBJECTIVE: UNVA 20/50 OU. No strabismus noted.
ASSESSMENT: Presbyopia, uncompensated.
PLAN: Prescribed +2.00 OU readers. Follow-up in 1 year."""
    sections = parse_chart(sample)
    assert "blurry near vision" in sections["subjective"]
    assert "UNVA 20/50" in sections["objective"]
    assert "Presbyopia" in sections["assessment"]
    assert "+2.00" in sections["plan"]


def test_parse_chart_tolerates_missing_sections():
    sections = parse_chart("SUBJECTIVE: Mild dryness.\nPLAN: Artificial tears QID.")
    assert "dryness" in sections["subjective"]
    assert sections["objective"] == ""
    assert "Artificial tears" in sections["plan"]


if __name__ == "__main__":
    for name, fn in sorted(list(globals().items())):
        if name.startswith("test_") and callable(fn):
            fn()
            print(f"ok  {name}")
    print("All scribe + recall tests passed.")
