# ADR-0003: Supabase (Postgres) replaces Firestore as the data layer

Date: 2026-10-02 · Status: Accepted · Supersedes: [ADR-0002](0002-firestore-first-v1.md)

## Context

ADR-0002 chose Firestore-first for v1 with Postgres as the known exit path.
The clinic product thesis (relational records: scheduling integrity, SQL
reporting, EHR-adjacent joins) made that exit probable, and the zero-migration
window — before any real patient record exists — was identified as the
cheapest moment. The owner decided to wire Supabase now rather than migrate
later.

## Decision

- **Supabase (Postgres + RLS + Realtime + Auth) is the platform data layer**,
  effective immediately: both Flutter apps, the ADK backend, and the seed
  tooling talk to Supabase only.
- Schema + policies live in `supabase/migrations/` as versioned SQL:
  `0001_initial_schema.sql` implements the DATA_MODEL with RLS policies that
  mirror the former firestore.rules (clinic_id tenancy, RBAC across
  Owner/Practitioner/Staff/Patient/Caregiver, append-only adherence signals,
  one-current-alert-per-patient SOS contract).
- Auth is Supabase Auth (GoTrue). Patient identities are real sessions; the
  zero-UI demo flow signs in as the seeded demo patient
  (`demo-patient@gozvision.demo`) so every copilot write satisfies RLS under
  a real identity — no policy exceptions for the demo.
- The backend uses the service-role key (bypasses RLS) — the trusted path for
  SOS writes from the agent, scribe drafts, and recall sweeps. The key lives
  only in `backend/.env` (gitignored).

## Consequences

- Scheduling integrity and Insights aggregation become plain SQL; the
  `notifications` queue is a table with real constraints.
- Realtime streams (SOS, outreach, fits, encounters) move from Firestore
  snapshots to `supabase_flutter` `.stream()` — same UX, different wire.
- ADR-0002's concern (relational depth vs Firestore) is resolved by adoption
  rather than deferred; its exit-path conditions will not re-trigger.
- Firestore/Firebase remain only in the frozen GozAI repo and as a *suggested*
  push-delivery provider in docs (no dependency).
- Patient-scoped ids are TEXT (auth uid or demo slug) — deliberate, keeps the
  copilot contract uniform; documented in the migration header.
