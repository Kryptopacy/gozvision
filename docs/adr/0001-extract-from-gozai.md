# ADR-0001: Extract GozVision into a new repository, GozAI frozen

Date: 2026-10-02 · Status: Accepted

## Context

GozAI is a hackathon submission (Gemini Live Agent Challenge). The product is
expanding from the low-vision copilot into a full patient–optometrist platform
(B2C copilot + B2B clinic suite). A new hackathon submission requires a new
app; the expansion changes the architecture (multi-tenant B2B, two apps, a
shared design system) and the audience (clinics, not only patients).

## Decision

- Build GozVision in a **new repository** (`gozvision`), monorepo layout.
- **Freeze GozAI** as the challenge artifact: no further feature work; it
  stays deployable for the existing demo.
- Copy portable assets (no history grafting) — see docs/EXTRACTION.md.

## Consequences

- Future architecture reviews of GozVision must not re-suggest building on
  the GozAI repo; the lineage is one-way (GozAI → GozVision).
- The hackathon submission and the product can evolve at different speeds.
- The verified GozAI refactor (Copilot Loop modules, tag contract, identity
  plumbing, RAG fix) is the foundation GozVision ports, not a loss.
