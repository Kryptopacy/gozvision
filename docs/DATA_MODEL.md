# GozVision data model (v1, Firestore-first)

Multi-tenant by construction: **every document carries `clinicId`** (except
self-serve patient data, where `clinicId` is null). Security rules deny any
read/write whose `clinicId` doesn't match the authenticated user's token.

```
clinics/{clinicId}                        # tenant root: name, branches, subscription
  practitioners/{uid}                     # optometrists: license, schedule, specialties
  staff/{uid}                             # front desk / technicians / dispensers (role)
  invitations/{id}                        # pending staff/practitioner onboards

patients/{patientId}                      # clinic-prescribed OR self-serve (clinicId: null)
  profile: name, dob, contact, clinicId, practitionerId, riskFlags
  assigned_caregivers: [uid]

users/{uid}                               # auth-linked RBAC doc (role: Patient|Caregiver|Staff|Practitioner|Owner)
  role, name, email, clinicId?, assigned_patients: [patientId]   # caregivers/ODs

appointments/{id}                         # clinicId, patientId, practitionerId, type, start, status
encounters/{id}                           # one visit: exam/follow-up/device-trial
  clinicId, patientId, appointmentId, type, startedAt, practitionerId
  scribe_draft: {status, sections{}, reviewedBy?}               # Scribe output — DRAFT until signed
low_vision_referrals/{id}                 # clinicId, patientId, from: practitionerId
  status: made | attended | lost_to_followup | declined
device_fits/{id}                          # clinicId, patientId, encounterId, device{type, model}, trialEndsAt
  status: trialing | prescribed | abandoned | sustained
  recentSignalCount: int                  # denormalized: recent signals for this fit,
                                          # maintained by the backend (job/CLI); drives
                                          # the Hub's abandonment-risk engine
adherence_signals/{id}                    # from the copilot — structured, NO media
  clinicId?, patientId, deviceFitId?, kind, value, at
  # kinds: daily_active_use, task_completion, struggle_detected, session_duration
notifications/{id}                        # recall engine output (see gozvision_agent/recall.py)
  clinicId, patientId, appointmentId?, kind: reminder|recovery|recall,
  channel: sms, message, status: queued|sent, createdAt, sentAt?, provider?
sos_alerts/{patientId}                    # inherited contract from GozAI (same schema + clinicId)
transcripts/{sessionId}                   # local-only session text (patient-scoped, HIPAA posture)
```

## Reading the model

- `users.assigned_patients` is the caregiver/practitioner → patient link that
  dashboards resolve (the GozAI `CaregiverDashboard` pattern, generalized).
- `encounters.scribe_draft` is draft-until-reviewed: the Scribe never writes
  final charts autonomously (CONTEXT.md — "Grounding over generation").
- `device_fits.status` + `adherence_signals` together power the Low Vision
  Hub's abandonment early-warning: a `trialing` fit with declining
  `daily_active_use` is the exact signature of the 29% abandonment leak.
- Alerts keep the GozAI document shape (`userId`, `resolved`, severity) so
  the ported `SosService` + backend tool work unchanged; `clinicId` is added.

## Deliberately out of scope for v1

Billing/insurance claims, inventory, and e-prescribing — integration depth
with existing PM/EHR systems (RevolutionEHR, Crystal PM) is its own phase and
its own ADR.
