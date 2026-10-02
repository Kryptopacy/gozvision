# ADR-0002: Firestore-first data layer for v1

Date: 2026-10-02 · Status: Superseded by [ADR-0003](0003-supabase-data-layer.md) the same day — see that ADR for the reasoning.

## Context

GozVision needs a data layer for both realtime copilot data (SOS alerts,
memory, adherence signals) and clinic records (patients, encounters, device
fits, scheduling). GozAI used Firestore throughout; the team knows it; the
copilot side genuinely needs realtime streams.

## Decision

v1 standardizes on **Firestore + Firebase Auth** for everything, with
`clinicId` tenancy enforced in security rules.

## Trade-offs accepted

- Relational/reporting queries (Insights) are weaker in Firestore; aggregates
  will be precomputed or via scheduled jobs until they hurt.
- Clinic record integrity (unique appointment slots, referential integrity)
  relies on transactions/rules rather than constraints.
- **Exit path:** Postgres (Cloud SQL) remains the known evolution for the
  clinic-records side if reporting or integrity needs outgrow Firestore.
  The `packages/domain` models are storage-agnostic to keep that door open.

Revisit this ADR when Insights analytics or scheduling integrity first
becomes a pain, not before.
