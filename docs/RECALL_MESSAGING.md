# Front Desk Recall Engine & AWS Messaging Specification

GozVision automates patient engagement, routine exam recalls, and appointment scheduling across both in-app and external communication channels.

---

## 1. Outreach Worklist Computation (`backend/gozvision_agent/recall.py`)

The recall sweep runs on a configurable time horizon (default: 14 days) and processes clinic appointment ledgers against three clinical conditions:

1. **Reminder:** Patient has an unconfirmed scheduled appointment inside the 14-day horizon.
2. **Recovery:** Patient had a `no_show` within the last 30 days. Triggers a warm, empathetic re-booking message emphasizing eye health.
3. **Annual Recall:** Patient has had no completed visit in $>365$ days and has no future appointment booked.

### Single-Touch Idempotency
A patient receives at most **one** outreach touch per sweep. The priority hierarchy is:
$$\text{Recovery (No-Show)} > \text{Reminder (Upcoming)} > \text{Annual Recall}$$

---

## 2. Two-Way Conversational Scheduling via AWS End User Messaging

Rather than sending one-way blast messages, GozVision supports **autonomous two-way conversation**:

```
[Patient on WhatsApp/SMS]: "Can I do next Tuesday at 3 PM?"
       │
       ▼ Inbound Webhook
[GozVision Engine (handle_inbound_patient_reply)]:
       ├── Audits clinic schedule on Supabase
       ├── Identifies match for Tuesday afternoon
       ▼
[AWS End User Messaging]:
       ├── Channel: WhatsApp (boto3 client 'socialmessaging' -> SendWhatsAppMessage)
       └── Channel: SMS (boto3 client 'pinpoint-sms-voice-v2' -> SendTextMessage)
       ▼
[Outgoing to Patient]: "We found an opening on Tuesday at 3:00 PM! Reply 'YES' to lock it in."
```

---

## 3. In-App Care Thread Chat System

For direct, authenticated communication within the clinic platform without third-party messaging apps:
* **Architecture:** PostgreSQL `conversations` and `messages` tables with Row-Level Security (RLS) policies.
* **Connected Parties:** Optometrists, Clinic Staff, Patients, and Family Caregivers.
* **Notification Dispatch:** Integrated with Supabase Realtime streams, complemented by push notifications and email delivery fallbacks for urgent updates.
* **UI Component:** [`apps/clinic/lib/modules/clinic_chat_dialog.dart`](file:///d:/pacy_labs/gozvision/apps/clinic/lib/modules/clinic_chat_dialog.dart) accessible via the Clinic Suite top action bar.
